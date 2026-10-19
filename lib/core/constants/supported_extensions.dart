enum ItemType {
  video,
  audio,
  pdf,
  txt,
  html,
  link,
  image,
  doc,
  ppt,
  epub,
  cbz,
  other,
}

const videoExtensions = {
  'mp4',
  'm4v',
  'mov',
  'mkv',
  'avi',
  'webm',
  'mpg',
  'mpeg',
  'ts',
  'm2ts',
  'ogv',
  '3gp',
  'vob',
};
const audioExtensions = {
  'mp3',
  'm4a',
  'm4b',
  'aac',
  'wav',
  'flac',
  'ogg',
  'opus',
  'wma',
  'aiff',
  'aif',
  'alac',
};
const pdfExtensions = {'pdf'};
const textExtensions = {'txt'};
const htmlExtensions = {'html', 'htm'};
const linkExtensions = {'url'};
const imageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'tif',
  'tiff',
  'heic',
};
const docExtensions = {'doc', 'docx'};
const pptExtensions = {'ppt', 'pptx'};
const epubExtensions = {'epub'};

ItemType inferItemType(String filename) {
  final lower = filename.toLowerCase();
  final ext = lower.contains('.') ? lower.split('.').last : '';

  if (videoExtensions.contains(ext)) return ItemType.video;
  if (audioExtensions.contains(ext)) return ItemType.audio;
  if (pdfExtensions.contains(ext)) return ItemType.pdf;
  if (textExtensions.contains(ext)) return ItemType.txt;
  if (htmlExtensions.contains(ext)) return ItemType.html;
  if (linkExtensions.contains(ext)) return ItemType.link;
  if (imageExtensions.contains(ext)) return ItemType.image;
  if (docExtensions.contains(ext)) return ItemType.doc;
  if (pptExtensions.contains(ext)) return ItemType.ppt;
  if (ext == 'cbz') return ItemType.cbz;
  if (epubExtensions.contains(ext)) return ItemType.epub;
  return ItemType.other;
}

bool isSupportedImportFile(String filename) {
  return inferItemType(filename) != ItemType.other;
}
