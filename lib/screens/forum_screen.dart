import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/gestures.dart';

class ForumScreen extends StatefulWidget {
  final String encryptedUrl;
  final String title;

  const ForumScreen({
    super.key,
    required this.encryptedUrl,
    required this.title,
  });

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _forumData;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadForumDetail();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadForumDetail() async {
    setState(() => _isLoading = true);

    try {
      final data = await _apiService.fetchForumDetail(widget.encryptedUrl);
      setState(() {
        _forumData = data;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendReply() async {
    if (_messageController.text.trim().isEmpty) {
      _showSnackBar('Pesan tidak boleh kosong');
      return;
    }

    if (_replyingTo == null) {
      _showSnackBar('Data reply tidak lengkap');
      return;
    }

    setState(() => _isSending = true);

    try {
      final formattedMessage = _convertWhatsAppFormatToHtml(_messageController.text.trim());
      
      await _apiService.submitForumReply(
        parentId: _replyingTo!['parent_id'] ?? '0',
        kdJdwEnc: _replyingTo!['kd_jdw_enc'] ?? '',
        idAktifitas: _replyingTo!['id_aktifitas'] ?? '',
        replyId: _replyingTo!['reply_id'] ?? '',
        forumNama: _replyingTo!['forum_nama'] ?? '',
        message: formattedMessage,
      );

      if (mounted) {
        _showSnackBar('Pesan berhasil dikirim');
        _messageController.clear();
        setState(() => _replyingTo = null);
        await Future.delayed(const Duration(seconds: 2));
        await _loadForumDetail();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e');
      }
    }

    setState(() => _isSending = false);
  }

  void _setReplyingTo(Map<String, dynamic> data, String authorName, String message) {
    setState(() {
      _replyingTo = {
        ...data,
        '_reply_author': authorName,
        '_reply_message': message,
      };
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _convertWhatsAppFormatToHtml(String text) {
    // Bold: *text* to <strong>text</strong>
    text = text.replaceAllMapped(
      RegExp(r'\*([^\*]+)\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );
    
    // Italic: _text_ to <em>text</em>
    text = text.replaceAllMapped(
      RegExp(r'_([^_]+)_'),
      (match) => '<em>${match.group(1)}</em>',
    );
    
    // Strikethrough: ~text~ to <s>text</s>
    text = text.replaceAllMapped(
      RegExp(r'~([^~]+)~'),
      (match) => '<s>${match.group(1)}</s>',
    );
    
    return '<p>$text</p>';
  }

  Widget _buildFormattedText(String htmlText) {
    try {
      final document = html_parser.parse(htmlText);
      final body = document.body;
      
      if (body == null) {
        return Text(htmlText);
      }
      
      return _buildTextSpanFromHtml(body);
    } catch (e) {
      return Text(htmlText);
    }
  }

  Widget _buildTextSpanFromHtml(dynamic element) {
    final spans = <InlineSpan>[];
    
    for (var node in element.nodes) {
      if (node.nodeType == 3) { // Text node
        spans.add(TextSpan(text: node.text));
      } else if (node.nodeType == 1) { // Element node
        final tag = (node as dynamic).localName;
        final text = node.text;
        
        TextStyle style = const TextStyle(fontSize: 14, color: Colors.black87);
        
        switch (tag) {
          case 'strong':
          case 'b':
            style = style.copyWith(fontWeight: FontWeight.bold);
            break;
          case 'em':
          case 'i':
            style = style.copyWith(fontStyle: FontStyle.italic);
            break;
          case 's':
          case 'strike':
          case 'del':
            style = style.copyWith(decoration: TextDecoration.lineThrough);
            break;
        }
        
        spans.add(TextSpan(text: text, style: style));
      }
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _forumData == null
              ? const Center(child: Text('Data forum tidak ditemukan'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMainPost(),
                            const SizedBox(height: 24),
                            
                            if (_forumData!['replies'] != null && (_forumData!['replies'] as List).isNotEmpty) ...[
                              const Text(
                                'Diskusi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._buildReplies(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    _buildReplyInput(),
                  ],
                ),
    );
  }

  Widget _buildMainPost() {
    final mainPost = _forumData!['main_post'] as Map<String, dynamic>;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: (mainPost['author_img'] != null && mainPost['author_img'].isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            mainPost['author_img'],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 28, color: Colors.grey);
                            },
                          ),
                        )
                      : const Icon(Icons.person, size: 28, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mainPost['author_name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mainPost['created_date'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainPost['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFormattedText(mainPost['content'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _setReplyingTo(
                  mainPost,
                  mainPost['author_name'] ?? '',
                  mainPost['content'] ?? '',
                ),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReplies() {
    final replies = _forumData!['replies'] as List;
    final widgets = <Widget>[];
    
    for (final reply in replies) {
      final replyMap = reply as Map<String, dynamic>;
      final isSubReply = replyMap['is_sub_reply'] ?? false;
      
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: isSubReply ? 32.0 : 0.0,
            bottom: 12,
          ),
          child: Card(
            color: isSubReply ? Colors.red.shade50 : Colors.blue.shade50,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[300],
                        child: (replyMap['author_img'] != null && replyMap['author_img'].isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  replyMap['author_img'],
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.person, size: 18, color: Colors.grey);
                                  },
                                ),
                              )
                            : const Icon(Icons.person, size: 18, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyMap['author_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              replyMap['date'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFormattedText(replyMap['message'] ?? ''),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _setReplyingTo(
                        replyMap,
                        replyMap['author_name'] ?? '',
                        replyMap['message'] ?? '',
                      ),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildReplyInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Colors.blue.shade700,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.reply, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Membalas ${_replyingTo!['_reply_author'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _replyingTo!['_reply_message'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        helperStyle: const TextStyle(fontSize: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      enabled: !_isSending,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _isSending || _replyingTo == null ? null : _sendReply,
                backgroundColor: Colors.blue,
                mini: true,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
