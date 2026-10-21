import 'media_catalog_repository.dart';

/// Product vocabulary and available actions follow the library's purpose.
/// A mixed library falls back to the actual resource type, never to Courses.
class MediaExperience {
  const MediaExperience(this.kind, this.itemType);
  final LibraryKind kind;
  final String itemType;
  bool get course => kind == LibraryKind.courses;
  bool get video => itemType == 'video';
  bool get audio => itemType == 'audio';
  bool get photo => itemType == 'image';
  bool get reading => {
    'pdf',
    'epub',
    'cbz',
    'text',
    'document',
    'txt',
    'md',
    'html',
  }.contains(itemType);
  bool get notes => course || reading;
  bool get longAudio =>
      {LibraryKind.audiobooks, LibraryKind.podcasts}.contains(kind);
  bool get completion => !photo && (course || video || reading || longAudio);
  bool get sequential => course || kind == LibraryKind.television;
  String get notesLabel => course ? 'Study' : 'Notes & bookmarks';
  String get noun => course
      ? 'lesson'
      : video
      ? 'video'
      : audio
      ? (longAudio ? 'episode' : 'track')
      : photo
      ? 'photo'
      : reading
      ? 'book or document'
      : 'file';
  String completionLabel(bool completed) => course
      ? completed
            ? 'Mark incomplete'
            : 'Mark complete'
      : video
      ? completed
            ? 'Mark unwatched'
            : 'Mark watched'
      : reading
      ? completed
            ? 'Mark unread'
            : 'Mark read'
      : completed
      ? 'Mark unplayed'
      : 'Mark finished';
  String get completedLabel => course
      ? 'Completed'
      : video
      ? 'Watched'
      : reading
      ? 'Read'
      : 'Finished';
}
