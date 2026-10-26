#include "include/tangerine_vlc/tangerine_vlc_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <memory>
#include <optional>
#include <cctype>
#include <windows.h>
#include "../native/vlc_session.h"
namespace {
using Value=flutter::EncodableValue;using Map=flutter::EncodableMap;
std::string Scalar(const Value& v) {
  if(auto p=std::get_if<std::string>(&v))return *p;
  if(auto p=std::get_if<int32_t>(&v))return std::to_string(*p);
  if(auto p=std::get_if<int64_t>(&v))return std::to_string(*p);
  if(auto p=std::get_if<double>(&v))return std::to_string(*p);
  if(auto p=std::get_if<bool>(&v))return *p?"true":"false";
  if(auto p=std::get_if<flutter::EncodableList>(&v)){std::string s;for(const auto& row:*p){if(!s.empty())s+=",";s+=Scalar(row);}return s;}
  return "";
}
tangerine::Args Flatten(const Map& rows) {
  tangerine::Args out;for(const auto& row:rows) {
    auto key=std::get_if<std::string>(&row.first);if(!key)continue;
    if(auto nested=std::get_if<Map>(&row.second)){for(const auto& sub:*nested)out[*key+"."+Scalar(sub.first)]=Scalar(sub.second);}
    else out[*key]=Scalar(row.second);
  }return out;
}
class Plugin : public flutter::Plugin {
 struct Entry {
   explicit Entry(const tangerine::Args& a):core(a) {}
   tangerine::VlcSession core;
   FlutterDesktopPixelBuffer pixels{};
   std::unique_ptr<flutter::TextureVariant> texture;
   int64_t texture_id=-1;
 };
 flutter::PluginRegistrarWindows* registrar_;
 std::unique_ptr<flutter::MethodChannel<Value>> channel_;
 std::map<int64_t,std::shared_ptr<Entry>> entries_;
 int64_t serial_=0;
 bool fullscreen_=false, resized_=false, close_allowed_=false;
 LONG_PTR style_=0;
 WINDOWPLACEMENT placement_{sizeof(WINDOWPLACEMENT)};
 tangerine::Args preferences_;
 std::string restored_key_;
 RECT last_frame_{};
 int window_proc_=-1;
 inline static std::vector<Plugin*> windows_;
 inline static Plugin* global_owner_=nullptr;
 std::map<std::string,std::string> global_bindings_;
 std::map<int,std::string> global_actions_;
 std::vector<std::string> shortcut_errors_;
 int64_t active_player_=0;
 void ReleaseGlobals(){for(const auto& row:global_actions_)UnregisterHotKey(Window(),row.first);global_actions_.clear();}
 void ActivateGlobals() {
   if(global_owner_&&global_owner_!=this)global_owner_->ReleaseGlobals();global_owner_=this;ReleaseGlobals();shortcut_errors_.clear();
   for(const auto& entry:global_bindings_) {
     if(entry.second.empty())continue;std::istringstream stream(entry.second);std::string part;std::vector<std::string> parts;
     while(std::getline(stream,part,'+')){part.erase(std::remove_if(part.begin(),part.end(),[](unsigned char c){return std::isspace(c);}),part.end());std::transform(part.begin(),part.end(),part.begin(),[](unsigned char c){return static_cast<char>(std::tolower(c));});parts.push_back(part);}
     if(parts.empty())continue;auto key=parts.back();parts.pop_back();UINT mods=MOD_NOREPEAT,vk=0;
     for(const auto& modifier:parts){if(modifier=="control"||modifier=="ctrl")mods|=MOD_CONTROL;else if(modifier=="alt"||modifier=="option")mods|=MOD_ALT;else if(modifier=="shift")mods|=MOD_SHIFT;else if(modifier=="command"||modifier=="cmd"||modifier=="meta")mods|=MOD_WIN;}
     const std::map<std::string,UINT> keys={{"space",VK_SPACE},{"left",VK_LEFT},{"right",VK_RIGHT},{"up",VK_UP},{"down",VK_DOWN},{"escape",VK_ESCAPE},{"return",VK_RETURN},{"tab",VK_TAB}};
     if(key.size()==1&&std::isalnum(static_cast<unsigned char>(key[0])))vk=static_cast<UINT>(std::toupper(static_cast<unsigned char>(key[0])));else if(keys.count(key))vk=keys.at(key);
     int identity=static_cast<int>(global_actions_.size())+1;
     if(!vk||(mods&~MOD_NOREPEAT)==0||!RegisterHotKey(Window(),identity,mods,vk)){shortcut_errors_.push_back("Global shortcut unavailable: "+entry.second);continue;}
     global_actions_[identity]=entry.first;
   }
 }

 void SaveFrame() {
   if(preferences_["rememberWindow"]=="false"||preferences_["windowFrameKey"].empty()||last_frame_.right<=last_frame_.left)return;
   HKEY key=nullptr;if(RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\Tangerine\\PlayerWindows",0,nullptr,0,KEY_SET_VALUE,nullptr,&key,nullptr)==ERROR_SUCCESS){auto name=Wide(preferences_["windowFrameKey"]);RegSetValueExW(key,name.c_str(),0,REG_BINARY,reinterpret_cast<const BYTE*>(&last_frame_),sizeof(last_frame_));RegCloseKey(key);}
 }

 HWND Window(){return GetAncestor(registrar_->GetView()->GetNativeWindow(),GA_ROOT);}
 static std::wstring Wide(const std::string& text){int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),nullptr,0);if(count<=0)return L"";std::wstring out(count,L'\0');MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),out.data(),count);return out;}
 void Fullscreen(bool enabled) {
   if(enabled==fullscreen_)return;auto window=Window();if(!window)return;
   if(enabled) {style_=GetWindowLongPtrW(window,GWL_STYLE);GetWindowPlacement(window,&placement_);MONITORINFO monitor{sizeof(MONITORINFO)};GetMonitorInfoW(preferences_["fullscreenScreen"]=="Main screen"?MonitorFromPoint(POINT{0,0},MONITOR_DEFAULTTOPRIMARY):MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor);SetWindowLongPtrW(window,GWL_STYLE,style_&~WS_OVERLAPPEDWINDOW);SetWindowPos(window,HWND_TOP,monitor.rcMonitor.left,monitor.rcMonitor.top,monitor.rcMonitor.right-monitor.rcMonitor.left,monitor.rcMonitor.bottom-monitor.rcMonitor.top,SWP_FRAMECHANGED);}
   else {SetWindowLongPtrW(window,GWL_STYLE,style_);SetWindowPlacement(window,&placement_);SetWindowPos(window,nullptr,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED);}
   fullscreen_=enabled;
 }
 void Preferences(const tangerine::Args& args) {
   for(const auto& row:args)if(row.first.rfind("values.",0)==0)preferences_[row.first.substr(7)]=row.second;
   auto window=Window();if(!window)return;
   SetWindowPos(window,preferences_["alwaysOnTop"]=="true"?HWND_TOPMOST:HWND_NOTOPMOST,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);
   if(!fullscreen_) {auto style=GetWindowLongPtrW(window,GWL_STYLE);SetWindowLongPtrW(window,GWL_STYLE,preferences_["decorations"]=="false"?style&~WS_CAPTION:style|WS_CAPTION);SetWindowPos(window,nullptr,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED);}
   auto frame_key=preferences_["windowFrameKey"];
   if(preferences_["rememberWindow"]!="false"&&!frame_key.empty()&&restored_key_!=frame_key) {
     restored_key_=frame_key;HKEY key=nullptr;
     if(RegOpenKeyExW(HKEY_CURRENT_USER,L"Software\\Tangerine\\PlayerWindows",0,KEY_QUERY_VALUE,&key)==ERROR_SUCCESS){RECT frame{};DWORD size=sizeof(frame),type=0;auto name=Wide(frame_key);if(RegQueryValueExW(key,name.c_str(),nullptr,&type,reinterpret_cast<BYTE*>(&frame),&size)==ERROR_SUCCESS&&type==REG_BINARY&&size==sizeof(frame)&&frame.right-frame.left>=320&&frame.bottom-frame.top>=200&&frame.right-frame.left<=7680&&frame.bottom-frame.top<=4320&&MonitorFromRect(&frame,MONITOR_DEFAULTTONULL))SetWindowPos(window,nullptr,frame.left,frame.top,frame.right-frame.left,frame.bottom-frame.top,SWP_NOZORDER|SWP_NOACTIVATE);RegCloseKey(key);}
   }
   const auto resize=preferences_["resizeVideo"];
   if(!fullscreen_ && (resize=="Always" || (resize=="On first video"&&!resized_)) && !preferences_["videoWidth"].empty() && !preferences_["videoHeight"].empty()) {
     double w=std::stod(preferences_["videoWidth"]),h=std::stod(preferences_["videoHeight"]);
     if(std::isfinite(w)&&std::isfinite(h)&&w>0&&h>0) {MONITORINFO monitor{sizeof(MONITORINFO)};GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor);double scale=std::min({1.,(monitor.rcWork.right-monitor.rcWork.left)*.85/w,(monitor.rcWork.bottom-monitor.rcWork.top)*.85/(h+140)});RECT size{0,0,static_cast<LONG>(std::max(480.,w*scale)),static_cast<LONG>(std::max(300.,h*scale+140))};AdjustWindowRectEx(&size,GetWindowLongPtrW(window,GWL_STYLE),FALSE,GetWindowLongPtrW(window,GWL_EXSTYLE));SetWindowPos(window,nullptr,0,0,size.right-size.left,size.bottom-size.top,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);resized_=true;}
   }
   SetWindowTextW(window,Wide(preferences_["filenameTitle"]=="false"?"Tangerine":preferences_["windowTitle"]).c_str());
   double opacity=preferences_["opacity"].empty()?1:std::stod(preferences_["opacity"]);opacity=std::clamp(opacity,.1,1.);
   SetWindowLongPtrW(window,GWL_EXSTYLE,GetWindowLongPtrW(window,GWL_EXSTYLE)|WS_EX_LAYERED);SetLayeredWindowAttributes(window,0,static_cast<BYTE>(opacity*255),LWA_ALPHA);
   if(preferences_["frontPlayback"]=="true"){ShowWindow(window,SW_RESTORE);SetForegroundWindow(window);}
 }
 static std::string Capabilities(){auto out=tangerine::VlcSession::Capabilities();out.pop_back();return out+",\"fullscreen\",\"escape\",\"windowPreferences\"]";}

 public:
 explicit Plugin(flutter::PluginRegistrarWindows* registrar):registrar_(registrar) {
   channel_=std::make_unique<flutter::MethodChannel<Value>>(registrar->messenger(),"tangerine/playback",&flutter::StandardMethodCodec::GetInstance());
   windows_.push_back(this);
   window_proc_=registrar_->RegisterTopLevelWindowProcDelegate([this](HWND,UINT message,WPARAM wparam,LPARAM)->std::optional<LRESULT>{
     if(message==WM_CLOSE&&!close_allowed_&&preferences_["independentPlaybackWindow"]=="true"&&entries_.count(active_player_)) {
       channel_->InvokeMethod("shortcut",std::make_unique<Value>(Map{{Value("id"),Value(active_player_)},{Value("action"),Value("window.close")}}));return 0;
     }
     if(message==WM_ACTIVATE&&LOWORD(wparam)!=WA_INACTIVE&&!entries_.empty())ActivateGlobals();
     if(message==WM_HOTKEY&&global_actions_.count(static_cast<int>(wparam))&&entries_.count(active_player_))channel_->InvokeMethod("shortcut",std::make_unique<Value>(Map{{Value("id"),Value(active_player_)},{Value("action"),Value(global_actions_.at(static_cast<int>(wparam)))}}));
     if(message==WM_SIZE&&wparam==SIZE_MINIMIZED&&preferences_["pauseMinimized"]=="true")for(auto& row:entries_)row.second->core.Command("pause",{});
     return std::nullopt;
   });
   channel_->SetMethodCallHandler([this](const auto& call,auto result){Handle(call,std::move(result));});
 }
 ~Plugin() override {ReleaseGlobals();windows_.erase(std::remove(windows_.begin(),windows_.end(),this),windows_.end());if(global_owner_==this){global_owner_=nullptr;if(!windows_.empty())windows_.back()->ActivateGlobals();}SaveFrame();registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_);channel_->SetMethodCallHandler(nullptr);for(auto& row:entries_)Release(row.second);entries_.clear();}
 void Release(const std::shared_ptr<Entry>& entry) {
   SaveFrame();entry->core.Close();
   registrar_->texture_registrar()->UnregisterTexture(entry->texture_id,[entry]{});
 }
 void Handle(const flutter::MethodCall<Value>& call,std::unique_ptr<flutter::MethodResult<Value>> result) {
   try {
     const Map empty;auto input=call.arguments()?std::get_if<Map>(call.arguments()):nullptr;
     auto args=Flatten(input?*input:empty);
     if(call.method_name()=="app.show"){ShowWindow(Window(),SW_RESTORE);SetForegroundWindow(Window());result->Success();return;}
     if(call.method_name()=="app.quit"){result->Success();PostQuitMessage(0);return;}
     if(call.method_name()=="preferences.catalog") {result->Success(Value(flutter::EncodableList{}));return;}
     if(call.method_name()=="create") {
       auto entry=std::make_shared<Entry>(args);auto raw=entry.get();
       entry->texture=std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture([raw](size_t,size_t)->const FlutterDesktopPixelBuffer* {
         uint32_t w=0,h=0;raw->pixels.buffer=raw->core.CopyFrame(&w,&h,false);raw->pixels.width=w;raw->pixels.height=h;
         return raw->pixels.buffer?&raw->pixels:nullptr;
       }));
       entry->texture_id=registrar_->texture_registrar()->RegisterTexture(entry->texture.get());
       if(entry->texture_id<0)throw std::runtime_error("Could not register video texture");
       auto texture_registrar=registrar_->texture_registrar();auto tid=entry->texture_id;
       entry->core.frame_ready=[texture_registrar,tid]{texture_registrar->MarkTextureFrameAvailable(tid);};
       const auto id=++serial_;entries_[id]=entry;active_player_=id;
       global_bindings_.clear();for(const auto& entry:args)if(entry.first.rfind("globalShortcuts.",0)==0)global_bindings_[entry.first.substr(16)]=entry.second;ActivateGlobals();
       result->Success(Value(Map{{Value("id"),Value(id)},{Value("textureId"),Value(tid)},{Value("capabilities"),Value(Capabilities())}}));return;
     }
     auto id=std::stoll(args.at("id"));auto it=entries_.find(id);
     if(it==entries_.end())throw std::runtime_error("Native player closed");
     if(call.method_name()=="dispose") {Release(it->second);entries_.erase(it);if(entries_.empty()){ReleaseGlobals();global_bindings_.clear();}result->Success();return;}
     if(call.method_name()=="state") {if(!fullscreen_)GetWindowRect(Window(),&last_frame_);std::string errors="[";for(const auto& error:shortcut_errors_){if(errors.size()>1)errors+=",";errors+=tangerine::Quote(error);}errors+="]";auto state=it->second->core.State(Capabilities(),",\"fullscreen\":"+std::string(fullscreen_?"true":"false")+",\"minimized\":"+std::string(IsIconic(Window())?"true":"false")+",\"shortcutErrors\":"+errors);result->Success(Value(state));return;}
     if(call.method_name()=="window.finish") {auto action=args["action"];result->Success();if(action=="Minimize")ShowWindow(Window(),SW_MINIMIZE);if(action=="Quit")PostQuitMessage(0);return;}
     if(call.method_name()=="window.close"){close_allowed_=true;SaveFrame();result->Success();PostMessageW(Window(),WM_CLOSE,0,0);return;}
     if(call.method_name()=="fullscreen"){Fullscreen(!fullscreen_);result->Success();return;}
     if(call.method_name()=="escape"){Fullscreen(false);result->Success();return;}
     if(call.method_name()=="window.preferences"){Preferences(args);result->Success();return;}
     it->second->core.Command(call.method_name(),args);result->Success();
   }catch(const std::exception& e){result->Error("LIBVLC",e.what());}
 }
};
}
void TangerineVlcPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
 auto wrapper=flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
 wrapper->AddPlugin(std::make_unique<Plugin>(wrapper));
}
