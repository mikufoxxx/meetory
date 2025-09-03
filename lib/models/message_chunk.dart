class MessageChunk {
  final String speaker;
  final String text;
  final Duration start;
  final Duration end;
  
  const MessageChunk({
    required this.speaker, 
    required this.text, 
    required this.start, 
    required this.end
  });
  
  Map<String, dynamic> toJson() {
    return {
      'speaker': speaker,
      'text': text,
      'start': start.inMilliseconds,
      'end': end.inMilliseconds,
    };
  }
  
  factory MessageChunk.fromJson(Map<String, dynamic> json) {
    return MessageChunk(
      speaker: json['speaker'] as String? ?? 'Unknown',
      text: json['text'] as String? ?? '',
      start: Duration(milliseconds: json['start'] as int? ?? 0),
      end: Duration(milliseconds: json['end'] as int? ?? 0),
    );
  }
}