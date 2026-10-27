#ifndef TANGERINE_VLC_SESSION_H
#define TANGERINE_VLC_SESSION_H
#include <vlc/vlc.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <memory>
#include <locale>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include "vlc_windows_symbols.h"

// libVLC 3 owns decoding. Flutter receives bounded software-rendered frames,
// including under Wayland; no X11 window-id or unauthenticated URL workaround.
namespace tangerine {
using Args = std::map<std::string,std::string>;
inline std::string Quote(const std::string& value) {
  std::ostringstream out; out << '"';
  for (unsigned char c:value) { if(c=='"'||c=='\\') out << '\\' << c; else if(c>=32) out << c; }
  out << '"'; return out.str();
}
class VlcSession {
 public:
  explicit VlcSession(const Args& args) {
    std::vector<std::string> options={"--no-video-title-show","--avcodec-hw=none"};
    const std::map<std::string,std::string> allowed={{"fileCache","file-caching"},{"networkCache","network-caching"},{"audioLanguage","audio-language"},{"subtitleLanguage","sub-language"},{"encoding","subsdec-encoding"},{"aout","aout"}};
    for(const auto& entry:allowed) {
      auto it=args.find("preferences."+entry.first);
      if(it!=args.end() && it->second.size()<=256 && it->second.find('\0')==std::string::npos) options.push_back("--"+entry.second+"="+it->second);
    }
    auto normalize=args.find("preferences.normalize");
    if(normalize!=args.end() && normalize->second=="true") {
      options.push_back("--audio-filter=normvol"); options.push_back("--norm-max-level=2");
    }
    const std::map<std::string,std::string> subtitle_options={{"subtitleSize","freetype-fontsize"},{"subtitleColor","freetype-color"}};
    for(const auto& entry:subtitle_options) {
      auto it=args.find("preferences."+entry.first);
      if(it!=args.end() && !it->second.empty() && it->second.size()<=10 && it->second.find_first_not_of("0123456789")==std::string::npos)
        options.push_back("--"+entry.second+"="+it->second);
    }
    std::vector<const char*> argv; for(auto& option:options) argv.push_back(option.c_str());
    instance_=libvlc_new(static_cast<int>(argv.size()),argv.data());
    if(!instance_) throw std::runtime_error("VideoLAN libVLC could not initialize. Check runtime/plugins.");
    player_=libvlc_media_player_new(instance_);
    if(!player_) {libvlc_release(instance_);instance_=nullptr;throw std::runtime_error("Could not create libVLC player");}
    libvlc_video_set_callbacks(player_,Lock,Unlock,Display,this);
    libvlc_video_set_format_callbacks(player_,Format,CleanupFormat);
  }
  ~VlcSession() { Close(); }
  VlcSession(const VlcSession&)=delete;
  VlcSession& operator=(const VlcSession&)=delete;
  std::function<void()> frame_ready;
  static std::string Capabilities() {return "[\"transport\",\"tracks\",\"chapters\",\"frame\",\"snapshot\",\"equalizer\",\"aspect\",\"crop\",\"zoom\",\"deinterlace\",\"brightness\",\"contrast\",\"saturation\",\"gamma\",\"hue\",\"audioDelay\",\"subtitleDelay\",\"devices\",\"diagnostics\"]";}
  void Close() {
    if(player_) {libvlc_media_player_stop(player_);frame_ready=nullptr;libvlc_media_player_release(player_);player_=nullptr;}
    if(instance_) {libvlc_release(instance_);instance_=nullptr;}
  }
  const uint8_t* CopyFrame(uint32_t* width,uint32_t* height,bool rgba) {
    std::lock_guard<std::mutex> guard(frame_mutex_);
    *width=width_;*height=height_;
    if(frame_.empty()) return nullptr;
    presented_=frame_;
    for(size_t i=0;i+3<presented_.size();i+=4) {if(rgba) std::swap(presented_[i],presented_[i+2]);presented_[i+3]=255;}
    return presented_.data();
  }
  std::string State(const std::string& capabilities=Capabilities(),const std::string& extra="") {
    auto state=libvlc_media_player_get_state(player_);
    unsigned w=0,h=0;libvlc_video_get_size(player_,0,&w,&h);
    std::ostringstream o; o.imbue(std::locale::classic());
    o << "{\"position\":" << std::max<int64_t>(0,libvlc_media_player_get_time(player_))
      << ",\"duration\":" << std::max<int64_t>(0,libvlc_media_player_get_length(player_))
      << ",\"playing\":" << (libvlc_media_player_is_playing(player_)?"true":"false")
      << ",\"completed\":" << (state==libvlc_Ended?"true":"false") << ",\"error\":" << (state==libvlc_Error?"true":"false")
      << ",\"buffering\":" << (state==libvlc_Buffering?"true":"false")
      << ",\"volume\":" << std::max(0,libvlc_audio_get_volume(player_)) << ",\"rate\":" << libvlc_media_player_get_rate(player_)
      << ",\"width\":" << w << ",\"height\":" << h << ",\"version\":" << Quote(libvlc_get_version())
      << ",\"audioTrack\":" << libvlc_audio_get_track(player_) << ",\"subtitleTrack\":" << libvlc_video_get_spu(player_)
      << ",\"chapter\":" << libvlc_media_player_get_chapter(player_) << ",\"chapters\":" << std::max(0,libvlc_media_player_get_chapter_count(player_))
      << ",\"audio\":" << Tracks(libvlc_audio_get_track_description(player_)) << ",\"subtitles\":" << Tracks(libvlc_video_get_spu_description(player_))
      << ",\"metadata\":" << Metadata() << ",\"audioDevice\":" << Quote(CurrentDevice()) << ",\"capabilities\":" << capabilities << ",\"statistics\":" << Statistics() << ",\"audioDevices\":" << Devices() << extra << "}";
    return o.str();
  }
  void Command(const std::string& method,const Args& args) {
    if(!player_) throw std::runtime_error("Player closed");
    auto str=[&](const char* key) {auto i=args.find(key);return i==args.end()?std::string():i->second;};
    auto num=[&](const char* key,double lo,double hi) {
      size_t used=0;double v=std::stod(str(key),&used);
      if(!std::isfinite(v)||used!=str(key).size()||v<lo||v>hi) throw std::runtime_error("Invalid player value");return v;
    };
    if(method=="open") {
      const auto uri=str("uri");
      if(uri.empty() || uri.size()>16384 || uri.find('\0')!=std::string::npos || (uri.rfind("file:",0)!=0 && uri.rfind("http:",0)!=0 && uri.rfind("https:",0)!=0 && uri.rfind("rtsp:",0)!=0 && uri.rfind("rtmp:",0)!=0 && uri.rfind("udp:",0)!=0 && uri.rfind("rtp:",0)!=0 && uri.rfind("srt:",0)!=0)) throw std::runtime_error("Invalid media address");
      auto media=libvlc_media_new_location(instance_,uri.c_str());if(!media) throw std::runtime_error("Media unavailable");
      libvlc_media_player_stop(player_);libvlc_media_player_set_media(player_,media);libvlc_media_release(media);
      if(libvlc_media_player_play(player_)!=0) throw std::runtime_error("Could not open media");
    } else if(method=="play") libvlc_media_player_play(player_);
    else if(method=="pause") libvlc_media_player_set_pause(player_,1);
    else if(method=="seek") libvlc_media_player_set_time(player_,static_cast<int64_t>(num("value",0,315576000000.0)));
    else if(method=="rate") {if(libvlc_media_player_set_rate(player_,static_cast<float>(num("value",.25,4))) != 0)throw std::runtime_error("Rate unsupported");}
    else if(method=="volume") libvlc_audio_set_volume(player_,static_cast<int>(num("value",0,100)));
    else if(method=="audioTrack") {if(libvlc_audio_set_track(player_,static_cast<int>(num("value",-1,100000))) != 0)throw std::runtime_error("Audio track unavailable");}
    else if(method=="subtitleTrack") {if(libvlc_video_set_spu(player_,static_cast<int>(num("value",-1,100000))) != 0)throw std::runtime_error("Subtitle track unavailable");}
    else if(method=="subtitle") {auto media=libvlc_media_new_path(instance_,str("value").c_str());if(!media)throw std::runtime_error("Subtitle unavailable");auto uri=libvlc_media_get_mrl(media);int result=uri?libvlc_media_player_add_slave(player_,libvlc_media_slave_type_subtitle,uri,true):-1;if(uri)libvlc_free(uri);libvlc_media_release(media);if(result!=0)throw std::runtime_error("Subtitle unavailable");}
    else if(method=="frame") {libvlc_media_player_set_pause(player_,1);libvlc_media_player_next_frame(player_);}
    else if(method=="snapshot") {auto path=str("destination");if(path.empty()||path.size()>16384||path.find('\0')!=std::string::npos||libvlc_video_take_snapshot(player_,0,path.c_str(),args.count("width")?static_cast<unsigned>(num("width",0,1920)):0,0)!=0)throw std::runtime_error("Snapshot unavailable");}
    else if(method=="chapter") {auto chapter=static_cast<int>(num("value",0,100000));auto count=libvlc_media_player_get_chapter_count(player_);if(chapter>=count)throw std::runtime_error("Chapter unavailable");libvlc_media_player_set_chapter(player_,chapter);}
    else if(method=="device") {auto id=str("value");if(!id.empty() && !HasDevice(id))throw std::runtime_error("Output device disconnected");libvlc_audio_output_device_set(player_,nullptr,id.empty()?nullptr:id.c_str());}
    else if(method=="picture") {
      for(auto key:{"brightness","contrast","saturation","gamma","hue"}) if(args.count(key)) {
        libvlc_video_set_adjust_int(player_,libvlc_adjust_Enable,1);
        const std::map<std::string,unsigned> fields={{"brightness",libvlc_adjust_Brightness},{"contrast",libvlc_adjust_Contrast},{"saturation",libvlc_adjust_Saturation},{"gamma",libvlc_adjust_Gamma},{"hue",libvlc_adjust_Hue}};
        libvlc_video_set_adjust_float(player_,fields.at(key),static_cast<float>(num(key,std::string(key)=="hue"?-180:0,std::string(key)=="hue"?180:10)));
      }
      for(auto key:{"aspect","crop"})if(args.count(key)) {auto value=str(key);if(value.size()>32||value.find_first_not_of("0123456789.:")!=std::string::npos)throw std::runtime_error("Invalid framing ratio");}
      if(args.count("deinterlaceMode")){const std::vector<std::string> modes={"off","blend","bob","linear","yadif","yadif2x"};if(std::find(modes.begin(),modes.end(),str("deinterlaceMode"))==modes.end())throw std::runtime_error("Invalid deinterlace mode");}
      if(args.count("aspect")) libvlc_video_set_aspect_ratio(player_,str("aspect").empty()?nullptr:str("aspect").c_str());
      if(args.count("crop")) libvlc_video_set_crop_geometry(player_,str("crop").empty()?nullptr:str("crop").c_str());
      if(args.count("zoom")) libvlc_video_set_scale(player_,static_cast<float>(num("zoom",0,5)));
      if(args.count("deinterlaceMode")) libvlc_video_set_deinterlace(player_,str("deinterlaceMode")=="off"?nullptr:str("deinterlaceMode").c_str());
      if(args.count("audioDelay")) libvlc_audio_set_delay(player_,static_cast<int64_t>(num("audioDelay",-60,60)*1000000));
      if(args.count("subtitleDelay")) libvlc_video_set_spu_delay(player_,static_cast<int64_t>(num("subtitleDelay",-60,60)*1000000));
    } else if(method=="equalizer") {
      if(str("enabled")=="true") {
        const auto preamp=static_cast<float>(num("preamp",-20,20));
        std::istringstream bands(str("bands"));std::string value;std::vector<float> values;
        while(std::getline(bands,value,',')) {size_t used=0;float v=std::stof(value,&used);if(used!=value.size()||!std::isfinite(v)||v < -20 ||v > 20)throw std::runtime_error("Invalid equalizer band");values.push_back(v);}
        if(values.size()!=10)throw std::runtime_error("Equalizer needs ten bands");
        auto release_eq=[](libvlc_equalizer_t* value){libvlc_audio_equalizer_release(value);};
        std::unique_ptr<libvlc_equalizer_t,decltype(release_eq)> eq(libvlc_audio_equalizer_new(),release_eq);
        if(!eq)throw std::runtime_error("Equalizer unavailable");
        libvlc_audio_equalizer_set_preamp(eq.get(),preamp);
        for(unsigned i=0;i<values.size();i++)libvlc_audio_equalizer_set_amp_at_index(eq.get(),values[i],i);
        if(libvlc_media_player_set_equalizer(player_,eq.get())!=0)throw std::runtime_error("Equalizer unavailable");
      } else libvlc_media_player_set_equalizer(player_,nullptr);
    } else throw std::runtime_error("Unsupported native command: "+method);
  }
 private:
  libvlc_instance_t* instance_=nullptr;
  libvlc_media_player_t* player_=nullptr;
  std::mutex frame_mutex_;
  unsigned width_=0,height_=0;
  std::vector<uint8_t> frame_,presented_;
  static unsigned Format(void** opaque,char* chroma,unsigned* w,unsigned* h,unsigned* pitch,unsigned* lines) {
    auto self=static_cast<VlcSession*>(*opaque);std::lock_guard<std::mutex> guard(self->frame_mutex_);
    if(!*w||!*h||*w>32768||*h>32768)return 0;
    double scale=std::min({1.,1920. / (*w),1080. / (*h)});
    *w=std::max(1u,static_cast<unsigned>(*w*scale));*h=std::max(1u,static_cast<unsigned>(*h*scale));
    chroma[0]='R';chroma[1]='V';chroma[2]='3';chroma[3]='2';
    *pitch=*w*4;*lines=*h;self->width_=*w;self->height_=*h;self->frame_.assign(static_cast<size_t>(*pitch)* *h,0);return 1;
  }
  static void CleanupFormat(void*) {}
  static void* Lock(void* opaque,void** planes) {auto self=static_cast<VlcSession*>(opaque);self->frame_mutex_.lock();*planes=self->frame_.data();return nullptr;}
  static void Unlock(void* opaque,void*,void* const*) {static_cast<VlcSession*>(opaque)->frame_mutex_.unlock();}
  static void Display(void* opaque,void*) {auto self=static_cast<VlcSession*>(opaque);if(self->frame_ready)self->frame_ready();}
  static std::string Tracks(libvlc_track_description_t* rows) {
    std::string out="[";unsigned count=0;
    for(auto row=rows;row&&count<128;row=row->p_next,++count) {if(count)out+=",";out+="{\"id\":"+std::to_string(row->i_id)+",\"title\":"+Quote(row->psz_name?row->psz_name:"")+"}";}
    if(rows)libvlc_track_description_list_release(rows);return out+"]";
  }
  std::string CurrentDevice() {auto value=libvlc_audio_output_device_get(player_);if(!value)return "";std::string out(value);libvlc_free(value);return out;}
  std::string Devices() {
    auto devices=libvlc_audio_output_device_enum(player_);std::string out="[";unsigned count=0;
    for(auto row=devices;row&&count<128;row=row->p_next,++count) {if(count)out+=",";out+="{\"id\":"+Quote(row->psz_device?row->psz_device:"")+",\"title\":"+Quote(row->psz_description?row->psz_description:"")+"}";}
    if(devices)libvlc_audio_output_device_list_release(devices);return out+"]";
  }
  bool HasDevice(const std::string& id) {auto list=libvlc_audio_output_device_enum(player_);bool found=false;for(auto row=list;row;row=row->p_next)if(row->psz_device&&id==row->psz_device)found=true;if(list)libvlc_audio_output_device_list_release(list);return found;}
  std::string Metadata() {
    auto media=libvlc_media_player_get_media(player_);if(!media)return "{}";
    std::string out="{";for(const auto& entry:std::map<std::string,libvlc_meta_t>{{"Title",libvlc_meta_Title},{"Artist",libvlc_meta_Artist},{"Album",libvlc_meta_Album},{"Genre",libvlc_meta_Genre}}) {auto value=libvlc_media_get_meta(media,entry.second);if(value){if(out.size()>1)out+=",";out+=Quote(entry.first)+":"+Quote(std::string(value).substr(0,2048));libvlc_free(value);}}
    libvlc_media_release(media);return out+"}";
  }
  std::string Statistics() {
    auto media=libvlc_media_player_get_media(player_);libvlc_media_stats_t stats{};
    if(!media)return "{}";bool valid=libvlc_media_get_stats(media,&stats);libvlc_media_release(media);if(!valid)return "{}";
    return "{\"decodedVideo\":"+std::to_string(stats.i_decoded_video)+",\"displayedPictures\":"+std::to_string(stats.i_displayed_pictures)+",\"lostPictures\":"+std::to_string(stats.i_lost_pictures)+",\"readBytes\":"+std::to_string(stats.i_read_bytes)+"}";
  }
};
}
#endif
