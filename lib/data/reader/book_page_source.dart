import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../core/utils/sort_utils.dart';
import 'safe_book_archive.dart';

class BookPage {
  const BookPage({this.image,this.html,this.title=''});
  final Uint8List? image;
  final String? html;
  final String title;
}
abstract class BookPageSource {
  int get pageCount;
  bool get reflowable;
  List<String> get titles;
  String locator(int canonicalPage);
  Future<BookPage> load(int canonicalPage);
  Future<void> dispose();
}
class ArchiveBookSource implements BookPageSource {
  ArchiveBookSource._(this.archive,this.paths,this.titles,this.reflowable);
  final SafeBookArchive archive;
  final List<String> paths;
  @override final List<String> titles;
  @override final bool reflowable;
  bool _disposed=false;
  static Future<ArchiveBookSource> open(String path,{required bool epub}) async {
    final archive=await SafeBookArchive.open(path);
    if(!epub) {
      final pages=archive.entries.keys.where((n)=>RegExp(r'\.(png|jpe?g|webp|gif|bmp)$',caseSensitive:false).hasMatch(n)&&!n.split('/').any((s)=>s.startsWith('.')||s=='__MACOSX')).toList()..sort(naturalCourseCompare);
      if(pages.isEmpty)throw const FormatException('No supported images in this comic');
      return ArchiveBookSource._(archive,pages,pages.map(p.posix.basename).toList(),false);
    }
    final container=XmlDocument.parse(await archive.text('META-INF/container.xml'));
    final root=container.descendants.whereType<XmlElement>().where((e)=>e.name.local=='rootfile').firstOrNull?.getAttribute('full-path');
    if(root==null)throw const FormatException('EPUB package missing');
    final package=XmlDocument.parse(await archive.text(root));
    final manifest=<String,String>{};
    for(final entry in package.descendants.whereType<XmlElement>().where((e)=>e.name.local=='item')) {
      final id=entry.getAttribute('id'),href=entry.getAttribute('href');
      if(id!=null&&href!=null) {
        final uri=Uri.parse(href);
        if(uri.hasScheme||uri.hasAuthority)throw const FormatException('External EPUB resource');
        manifest[id]=SafeBookArchive.normalizeName(p.posix.join(p.posix.dirname(root),Uri.decodeComponent(uri.path)));
      }
    }
    final pages=<String>[];
    for(final spine in package.descendants.whereType<XmlElement>().where((e)=>e.name.local=='itemref'&&e.getAttribute('linear')!='no')) {
      final resource=manifest[spine.getAttribute('idref')];
      if(resource!=null)pages.add(resource);
    }
    if(pages.isEmpty)throw const FormatException('EPUB reading order missing');
    final fixed=package.descendants.whereType<XmlElement>().any((e)=>e.name.local=='meta'&&e.getAttribute('property')=='rendition:layout'&&e.innerText.trim()=='pre-paginated');
    return ArchiveBookSource._(archive,pages,List.generate(pages.length,(i)=>'Chapter ${i+1}'),!fixed);
  }
  @override int get pageCount=>paths.length;
  @override String locator(int canonicalPage)=>paths[canonicalPage-1];
  @override Future<BookPage> load(int canonicalPage) async {
    if(_disposed)throw StateError('Reader closed');
    final path=paths[canonicalPage-1];
    if(!path.endsWith('.xhtml')&&!path.endsWith('.html')&&!path.endsWith('.htm'))return BookPage(image:await archive.read(path),title:titles[canonicalPage-1]);
    final xml=XmlDocument.parse(await archive.text(path));
    if(!reflowable) {
      final images=xml.descendants.whereType<XmlElement>().where((e)=>e.name.local=='img'||e.name.local=='image').toList();
      if(images.length!=1)throw const FormatException('This fixed-layout EPUB requires a single image per page. Complex fixed-layout pages are not supported.');
      final image=images.single;
      final href=image.getAttribute('src')??image.getAttribute('href')??image.attributes.where((a)=>a.name.local=='href').firstOrNull?.value;
      if(href==null||Uri.parse(href).hasScheme)throw const FormatException('Invalid fixed-layout image');
      final resource=SafeBookArchive.normalizeName(p.posix.join(p.posix.dirname(path),Uri.decodeComponent(href)));
      return BookPage(image:await archive.read(resource),title:titles[canonicalPage-1]);
    }
    // Reflowable chapters keep text locators independently of screen pagination.
    // Only textual markup is retained; scripts, styles, forms and external assets
    // never enter the reader tree.
    const allowed={'p','div','span','h1','h2','h3','h4','h5','h6','em','strong','b','i','u','s','ul','ol','li','blockquote','pre','code','br','hr','section','article','sup','sub'};
    String safe(XmlNode node) {
      if(node is XmlText)return const HtmlEscape().convert(node.value);
      if(node is! XmlElement)return '';
      final name=node.name.local.toLowerCase();
      if({'script','style','iframe','object','form','svg','head'}.contains(name))return '';
      final children=node.children.map(safe).join();
      return allowed.contains(name)?'<$name>$children</$name>':children;
    }
    return BookPage(html:safe(xml.rootElement),title:titles[canonicalPage-1]);
  }
  @override Future<void> dispose() async {_disposed=true;}
}
