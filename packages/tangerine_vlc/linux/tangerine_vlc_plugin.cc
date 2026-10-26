#include "include/tangerine_vlc/tangerine_vlc_plugin.h"
#include "../native/vlc_session.h"

struct _TangerineTexture { FlPixelBufferTexture parent_instance; tangerine::VlcSession* core; FlTextureRegistrar* registrar; gint pending; gint closed; };
struct TangerineTextureClass { FlPixelBufferTextureClass parent_class; };
using TangerineTexture=struct _TangerineTexture;
G_DEFINE_TYPE(TangerineTexture,tangerine_texture,fl_pixel_buffer_texture_get_type())
static gboolean texture_pixels(FlPixelBufferTexture* base,const uint8_t** buffer,uint32_t* width,uint32_t* height,GError**) {
 auto self=reinterpret_cast<TangerineTexture*>(base);*buffer=self->core->CopyFrame(width,height,true);return *buffer!=nullptr;
}
static void texture_finalize(GObject* object) {auto self=reinterpret_cast<TangerineTexture*>(object);delete self->core;g_clear_object(&self->registrar);G_OBJECT_CLASS(tangerine_texture_parent_class)->finalize(object);}
static void tangerine_texture_class_init(TangerineTextureClass* klass) {FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels=texture_pixels;G_OBJECT_CLASS(klass)->finalize=texture_finalize;}
static void tangerine_texture_init(TangerineTexture* self) {self->core=nullptr;self->registrar=nullptr;self->pending=0;self->closed=0;}
static void release_texture(TangerineTexture* texture) {
 g_atomic_int_set(&texture->closed,1);texture->core->Close();fl_texture_registrar_unregister_texture(texture->registrar,FL_TEXTURE(texture));g_object_unref(texture);
}
static std::string scalar(FlValue* value) {
 if(!value)return "";
 switch(fl_value_get_type(value)) {
 case FL_VALUE_TYPE_STRING:return fl_value_get_string(value);
 case FL_VALUE_TYPE_INT:return std::to_string(fl_value_get_int(value));
 case FL_VALUE_TYPE_FLOAT:return std::to_string(fl_value_get_float(value));
 case FL_VALUE_TYPE_BOOL:return fl_value_get_bool(value)?"true":"false";
 case FL_VALUE_TYPE_LIST:{std::string out;for(size_t i=0;i<fl_value_get_length(value);i++){if(i)out+=",";out+=scalar(fl_value_get_list_value(value,i));}return out;}
 default:return "";
 }
}
static tangerine::Args flatten(FlValue* args) {
 tangerine::Args out;if(!args||fl_value_get_type(args)!=FL_VALUE_TYPE_MAP)return out;
 for(size_t i=0;i<fl_value_get_length(args);i++) {
   auto key=scalar(fl_value_get_map_key(args,i));auto value=fl_value_get_map_value(args,i);
   if(fl_value_get_type(value)==FL_VALUE_TYPE_MAP) {for(size_t n=0;n<fl_value_get_length(value);n++)out[key+"."+scalar(fl_value_get_map_key(value,n))]=scalar(fl_value_get_map_value(value,n));}
   else out[key]=scalar(value);
 }return out;
}
struct _TangerineVlcPlugin {GObject parent_instance;std::map<int64_t,TangerineTexture*>* sessions;FlTextureRegistrar* textures;GtkWindow* window;gboolean fullscreen,resized,closing;FlMethodChannel* channel;tangerine::Args* preferences;std::string* restored;int width,height,x,y;int64_t serial;};
struct TangerineVlcPluginClass {GObjectClass parent_class;};
using TangerineVlcPlugin=struct _TangerineVlcPlugin;
G_DEFINE_TYPE(TangerineVlcPlugin,tangerine_vlc_plugin,g_object_get_type())
static gchar* frame_file(){g_autofree gchar* directory=g_build_filename(g_get_user_config_dir(),"tangerine",nullptr);g_mkdir_with_parents(directory,0700);return g_build_filename(directory,"player-windows.ini",nullptr);}
static void save_frame(TangerineVlcPlugin* self){
 if(!self->preferences||(*self->preferences)["rememberWindow"]=="false"||(*self->preferences)["windowFrameKey"].empty()||self->width<320)return;
 g_autofree gchar* path=frame_file();g_autoptr(GKeyFile) file=g_key_file_new();g_key_file_load_from_file(file,path,G_KEY_FILE_NONE,nullptr);auto key=(*self->preferences)["windowFrameKey"];
 g_key_file_set_integer(file,key.c_str(),"width",self->width);g_key_file_set_integer(file,key.c_str(),"height",self->height);g_key_file_set_integer(file,key.c_str(),"x",self->x);g_key_file_set_integer(file,key.c_str(),"y",self->y);g_key_file_save_to_file(file,path,nullptr);
}
static void plugin_dispose(GObject* object) {
 auto self=reinterpret_cast<TangerineVlcPlugin*>(object);
 save_frame(self);
 if(self->sessions){for(auto& row:*self->sessions)release_texture(row.second);delete self->sessions;self->sessions=nullptr;}
 delete self->preferences;self->preferences=nullptr;delete self->restored;self->restored=nullptr;g_clear_object(&self->window);g_clear_object(&self->textures);G_OBJECT_CLASS(tangerine_vlc_plugin_parent_class)->dispose(object);
}
static void tangerine_vlc_plugin_class_init(TangerineVlcPluginClass* klass) {G_OBJECT_CLASS(klass)->dispose=plugin_dispose;}
static void tangerine_vlc_plugin_init(TangerineVlcPlugin* self) {self->sessions=new std::map<int64_t,TangerineTexture*>();self->textures=nullptr;self->window=nullptr;self->fullscreen=FALSE;self->resized=FALSE;self->closing=FALSE;self->channel=nullptr;self->preferences=new tangerine::Args();self->restored=new std::string();self->width=0;self->height=0;self->x=0;self->y=0;self->serial=0;}
static std::string desktop_capabilities(){auto out=tangerine::VlcSession::Capabilities();out.pop_back();return out+",\"fullscreen\",\"escape\",\"windowPreferences\"]";}
static void handle_call(FlMethodChannel*,FlMethodCall* call,gpointer data) {
 auto self=static_cast<TangerineVlcPlugin*>(data);
 g_autoptr(FlMethodResponse) response=nullptr;
 try {
  auto args=flatten(fl_method_call_get_args(call));std::string method=fl_method_call_get_name(call);
  if(method=="app.show"){gtk_window_deiconify(self->window);gtk_window_present(self->window);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
  else if(method=="app.quit"){g_idle_add([](gpointer)->gboolean{auto app=g_application_get_default();if(app)g_application_quit(app);return G_SOURCE_REMOVE;},nullptr);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
  else if(method=="preferences.catalog") {g_autoptr(FlValue) rows=fl_value_new_list();response=FL_METHOD_RESPONSE(fl_method_success_response_new(rows));}
  else if(method=="create") {
   auto core=std::make_unique<tangerine::VlcSession>(args);
   auto texture=reinterpret_cast<TangerineTexture*>(g_object_new(tangerine_texture_get_type(),nullptr));texture->core=core.release();texture->registrar=FL_TEXTURE_REGISTRAR(g_object_ref(self->textures));
   if(!fl_texture_registrar_register_texture(self->textures,FL_TEXTURE(texture))){g_object_unref(texture);throw std::runtime_error("Could not register video texture");}
   texture->core->frame_ready=[texture]{
     if(g_atomic_int_get(&texture->closed)||!g_atomic_int_compare_and_exchange(&texture->pending,0,1))return;
     g_object_ref(texture);
     g_main_context_invoke(nullptr,[](gpointer data)->gboolean {auto t=static_cast<TangerineTexture*>(data);g_atomic_int_set(&t->pending,0);if(!g_atomic_int_get(&t->closed))fl_texture_registrar_mark_texture_frame_available(t->registrar,FL_TEXTURE(t));g_object_unref(t);return G_SOURCE_REMOVE;},texture);
   };
   auto id=++self->serial;(*self->sessions)[id]=texture;
   g_autoptr(FlValue) value=fl_value_new_map();fl_value_set_string_take(value,"id",fl_value_new_int(id));fl_value_set_string_take(value,"textureId",fl_value_new_int(fl_texture_get_id(FL_TEXTURE(texture))));fl_value_set_string_take(value,"capabilities",fl_value_new_string(desktop_capabilities().c_str()));response=FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else {
   auto id=std::stoll(args.at("id"));auto it=self->sessions->find(id);if(it==self->sessions->end())throw std::runtime_error("Native player closed");
   if(method=="dispose") {save_frame(self);release_texture(it->second);self->sessions->erase(it);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
   else if(method=="state") {if(!self->fullscreen){gtk_window_get_size(self->window,&self->width,&self->height);gtk_window_get_position(self->window,&self->x,&self->y);}auto state=it->second->core->State(desktop_capabilities(),",\"fullscreen\":"+std::string(self->fullscreen?"true":"false")+",\"minimized\":"+std::string((gtk_widget_get_window(GTK_WIDGET(self->window))&&(gdk_window_get_state(gtk_widget_get_window(GTK_WIDGET(self->window)))&GDK_WINDOW_STATE_ICONIFIED))?"true":"false"));g_autoptr(FlValue) value=fl_value_new_string(state.c_str());response=FL_METHOD_RESPONSE(fl_method_success_response_new(value));}
   else if(method=="window.finish") {if(args["action"]=="Minimize")gtk_window_iconify(self->window);if(args["action"]=="Quit")g_idle_add([](gpointer)->gboolean{auto app=g_application_get_default();if(app)g_application_quit(app);return G_SOURCE_REMOVE;},nullptr);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
   else if(method=="window.close") {
     self->closing=TRUE;save_frame(self);auto window=GTK_WINDOW(g_object_ref(self->window));
     g_idle_add_full(G_PRIORITY_DEFAULT_IDLE,[](gpointer data)->gboolean{gtk_widget_destroy(GTK_WIDGET(data));return G_SOURCE_REMOVE;},window,g_object_unref);
     response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
   }
   else if(method=="fullscreen"||method=="escape") {self->fullscreen=method=="fullscreen"?!self->fullscreen:FALSE;if(self->fullscreen){
     auto screen=gtk_window_get_screen(self->window);
     if((*self->preferences)["fullscreenScreen"]=="Main screen") {auto display=gdk_screen_get_display(screen);auto monitor=gdk_display_get_primary_monitor(display);int index=0;if(monitor)for(int i=0;i<gdk_display_get_n_monitors(display);i++)if(gdk_display_get_monitor(display,i)==monitor)index=i;gtk_window_fullscreen_on_monitor(self->window,screen,index);}
     else gtk_window_fullscreen(self->window);
   }else gtk_window_unfullscreen(self->window);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
   else if(method=="window.preferences") {
     for(const auto& entry:args)if(entry.first.rfind("values.",0)==0)(*self->preferences)[entry.first.substr(7)]=entry.second;
     auto frame_key=args["values.windowFrameKey"];
     if(args["values.rememberWindow"]!="false"&&!frame_key.empty()&&*self->restored!=frame_key){*self->restored=frame_key;g_autofree gchar* path=frame_file();g_autoptr(GKeyFile) file=g_key_file_new();if(g_key_file_load_from_file(file,path,G_KEY_FILE_NONE,nullptr)){int w=g_key_file_get_integer(file,frame_key.c_str(),"width",nullptr),h=g_key_file_get_integer(file,frame_key.c_str(),"height",nullptr);if(w>=320&&w<=7680&&h>=200&&h<=4320){gtk_window_resize(self->window,w,h);gtk_window_move(self->window,g_key_file_get_integer(file,frame_key.c_str(),"x",nullptr),g_key_file_get_integer(file,frame_key.c_str(),"y",nullptr));}}}
     const auto resize=args["values.resizeVideo"];
     if(!self->fullscreen&&(resize=="Always"||(resize=="On first video"&&!self->resized))&&!args["values.videoWidth"].empty()&&!args["values.videoHeight"].empty()) {
       double w=std::stod(args["values.videoWidth"]),h=std::stod(args["values.videoHeight"]);
       if(std::isfinite(w)&&std::isfinite(h)&&w>0&&h>0){GdkRectangle bounds{0,0,1600,1000};auto native=gtk_widget_get_window(GTK_WIDGET(self->window));auto display=gtk_widget_get_display(GTK_WIDGET(self->window));auto monitor=native?gdk_display_get_monitor_at_window(display,native):gdk_display_get_primary_monitor(display);if(monitor)gdk_monitor_get_workarea(monitor,&bounds);double scale=std::min({1.,bounds.width*.85/w,bounds.height*.85/(h+140)});gtk_window_resize(self->window,std::max(480,static_cast<int>(w*scale)),std::max(300,static_cast<int>(h*scale+140)));self->resized=TRUE;}
     }
     gtk_window_set_keep_above(self->window,args["values.alwaysOnTop"]=="true");
     gtk_window_set_decorated(self->window,args["values.decorations"]!="false");
     gtk_window_set_title(self->window,args["values.filenameTitle"]=="false"?"Tangerine":args["values.windowTitle"].c_str());
     if(args.count("values.opacity"))gtk_widget_set_opacity(GTK_WIDGET(self->window),std::clamp(std::stod(args["values.opacity"]),.1,1.));
     if(args["values.frontPlayback"]=="true")gtk_window_present(self->window);
     response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
   }
   else {it->second->core->Command(method,args);response=FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));}
  }
 }catch(const std::exception& e){response=FL_METHOD_RESPONSE(fl_method_error_response_new("LIBVLC",e.what(),nullptr));}
 fl_method_call_respond(call,response,nullptr);
}
void tangerine_vlc_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
 auto plugin=static_cast<TangerineVlcPlugin*>(g_object_new(tangerine_vlc_plugin_get_type(),nullptr));plugin->window=GTK_WINDOW(g_object_ref(gtk_widget_get_toplevel(GTK_WIDGET(fl_plugin_registrar_get_view(registrar)))));plugin->textures=FL_TEXTURE_REGISTRAR(g_object_ref(fl_plugin_registrar_get_texture_registrar(registrar)));
 g_signal_connect_object(plugin->window,"window-state-event",G_CALLBACK(+[](GtkWidget*,GdkEventWindowState* event,gpointer data)->gboolean {auto owner=static_cast<TangerineVlcPlugin*>(data);if((event->new_window_state&GDK_WINDOW_STATE_ICONIFIED)&&(*owner->preferences)["pauseMinimized"]=="true")for(auto& row:*owner->sessions)row.second->core->Command("pause",{});return FALSE;}),plugin,G_CONNECT_DEFAULT);
 g_autoptr(FlStandardMethodCodec) codec=fl_standard_method_codec_new();
 g_autoptr(FlMethodChannel) channel=fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),"tangerine/playback",FL_METHOD_CODEC(codec));
 plugin->channel=channel;
 g_signal_connect_object(plugin->window,"delete-event",G_CALLBACK(+[](GtkWidget*,GdkEvent*,gpointer data)->gboolean {
   auto self=static_cast<TangerineVlcPlugin*>(data);
   if(!self->closing&&self->sessions&&!self->sessions->empty()&&(*self->preferences)["independentPlaybackWindow"]=="true") {
     g_autoptr(FlValue) args=fl_value_new_map();fl_value_set_string_take(args,"id",fl_value_new_int(self->sessions->begin()->first));fl_value_set_string_take(args,"action",fl_value_new_string("window.close"));fl_method_channel_invoke_method(self->channel,"shortcut",args,nullptr,nullptr,nullptr);return TRUE;
   }return FALSE;
 }),plugin,G_CONNECT_DEFAULT);
 fl_method_channel_set_method_call_handler(channel,handle_call,g_object_ref(plugin),g_object_unref);g_object_unref(plugin);
}
