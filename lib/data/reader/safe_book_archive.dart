import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;
import 'package:path/path.dart' as p;

class BookArchiveEntry {
  const BookArchiveEntry(this.name,this.offset,this.compressedSize,this.size,this.method,this.crc);
  final String name;
  final int offset,compressedSize,size,method,crc;
}

/// Random access ZIP reader. Never extracts names onto the filesystem.
/// ZIP64, encryption, symlinks and unsupported codecs fail explicitly.
class SafeBookArchive {
  SafeBookArchive._(this.path,this.entries);
  final String path;
  final Map<String,BookArchiveEntry> entries;
  static const maxEntryBytes=64*1024*1024,maxEntries=10000,maxTotalBytes=2*1024*1024*1024;
  static String normalizeName(String value) {
    final name=value.replaceAll('\\','/');
    if(name.contains('\u0000')||name.startsWith('/')||RegExp(r'^[a-zA-Z]:').hasMatch(name)||name.split('/').contains('..')) throw const FormatException('Unsafe archive path');
    return p.posix.normalize(name);
  }
  static Future<SafeBookArchive> open(String path) async {
    final f=await File(path).open();
    try {
      final length=await f.length();
      if(length<22) throw const FormatException('Invalid book archive');
      final tailLength=length.clamp(0,65557);
      await f.setPosition(length-tailLength);
      final tail=await f.read(tailLength), view=ByteData.sublistView(tail);
      var end=-1;
      for(var i=tail.length-22;i>=0;i--) {
        if(view.getUint32(i,Endian.little)==0x06054b50 && i+22+view.getUint16(i+20,Endian.little)==tail.length) {end=i;break;}
      }
      if(end<0) throw const FormatException('Missing ZIP directory');
      int u16(int at)=>view.getUint16(end+at,Endian.little);
      int u32(int at)=>view.getUint32(end+at,Endian.little);
      final count=u16(10), size=u32(12), offset=u32(16);
      if(u16(4)!=0||u16(6)!=0||u16(8)!=count||count==65535||count>maxEntries||size>8*1024*1024||offset+size>length-tailLength+end) throw const FormatException('Unsupported or oversized ZIP directory');
      await f.setPosition(offset);
      final bytes=await f.read(size), d=ByteData.sublistView(bytes);
      var pos=0,total=0;
      final entries=<String,BookArchiveEntry>{};
      for(var i=0;i<count;i++) {
        if(pos+46>bytes.length||d.getUint32(pos,Endian.little)!=0x02014b50) throw const FormatException('Invalid ZIP entry');
        int u16(int at)=>d.getUint16(pos+at,Endian.little);
        int u32(int at)=>d.getUint32(pos+at,Endian.little);
        final flags=u16(8),method=u16(10),compressed=u32(20),uncompressed=u32(24),nameLength=u16(28),extra=u16(30),comment=u16(32),local=u32(42);
        if(pos+46+nameLength+extra+comment>bytes.length) throw const FormatException('Truncated ZIP entry');
        final name=normalizeName(utf8.decode(bytes.sublist(pos+46,pos+46+nameLength),allowMalformed:flags&0x800==0));
        final mode=u32(38)>>16;
        total+=uncompressed;
        if(flags&1!=0 || (method!=0&&method!=8) || (mode&0xf000)==0xa000 || uncompressed>maxEntryBytes || total>maxTotalBytes || (compressed==0&&uncompressed>0) || uncompressed>compressed*1000+1024 || local+30+compressed>offset) throw const FormatException('Unsupported or oversized archive entry');
        if(entries.containsKey(name)) throw const FormatException('Duplicate archive entry');
        if(!name.endsWith('/')) entries[name]=BookArchiveEntry(name,local,compressed,uncompressed,method,u32(16));
        pos+=46+nameLength+extra+comment;
      }
      return SafeBookArchive._(path,entries);
    } finally {await f.close();}
  }
  Future<Uint8List> read(String name,{int limit=maxEntryBytes}) async {
    final entry=entries[normalizeName(name)];
    if(entry==null||entry.size>limit) throw const FormatException('Book resource missing or too large');
    final f=await File(path).open();
    late int start;
    try {
      await f.setPosition(entry.offset);
      final header=await f.read(30);
      if(header.length!=30) throw const FormatException('Truncated archive');
      final d=ByteData.sublistView(header);
      if(d.getUint32(0,Endian.little)!=0x04034b50 || d.getUint16(8,Endian.little)!=entry.method) throw const FormatException('Invalid archive entry header');
      start=entry.offset+30+d.getUint16(26,Endian.little)+d.getUint16(28,Endian.little);
      if(start+entry.compressedSize>await f.length())throw const FormatException('Truncated archive resource');
    } finally {await f.close();}
    Stream<List<int>> stream=File(path).openRead(start,start+entry.compressedSize);
    if(entry.method==8)stream=stream.transform(ZLibDecoder(raw:true));
    final out=BytesBuilder(copy:false);
    await for(final chunk in stream) {
      if(out.length+chunk.length>limit||out.length+chunk.length>entry.size)throw const FormatException('Archive expansion limit exceeded');
      out.add(chunk);
    }
    final bytes=out.takeBytes();
    if(bytes.length!=entry.size||getCrc32(bytes)!=entry.crc)throw const FormatException('Damaged archive resource');
    return bytes;
  }
  Future<String> text(String name)=>read(name,limit:2*1024*1024).then(utf8.decode);
}
