import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../models/pertemuan_model.dart';
import 'assignment_screen.dart';
import 'forum_screen.dart';

class PertemuanDetailScreen extends StatefulWidget {
  final String? encryptedUrl;
  final String? title;
  final String? encryptedKelasId;
  final String? namaMataKuliah;
  final String? kodeMataKuliah;
  final String? mataKuliah;
  final int? pertemuanKe;

  const PertemuanDetailScreen({
    super.key,
    this.encryptedUrl,
    this.title,
    this.encryptedKelasId,
    this.namaMataKuliah,
    this.kodeMataKuliah,
    this.mataKuliah,
    this.pertemuanKe,
  });

  @override
  State<PertemuanDetailScreen> createState() => _PertemuanDetailScreenState();
}

class _PertemuanDetailScreenState extends State<PertemuanDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<MateriItem> _materiList = [];

  @override
  void initState() {
    super.initState();
    _loadPertemuanDetail();
  }

  Future<void> _loadPertemuanDetail() async {
    setState(() => _isLoading = true);

    try {
      final urlToFetch = widget.encryptedKelasId ?? widget.encryptedUrl;
      
      if (urlToFetch != null) {
        final html = await _apiService.fetchPertemuanPage(urlToFetch);
        
        if (html != null) {
          _parseHtmlContent(html);
        }
      }
    } catch (e) {
      print('Error loading pertemuan detail: $e');
    }

    setState(() => _isLoading = false);
  }

  void _parseHtmlContent(String html) {
    final document = html_parser.parse(html);
    final List<MateriItem> items = [];

    final boxBody = document.querySelector('div.box-body');
    if (boxBody != null) {
      final tableInBox = boxBody.querySelector('table');
      if (tableInBox != null) {
        final rows = tableInBox.querySelectorAll('tbody tr');
        if (rows.isNotEmpty) {
          _parseMateriRows(rows, items);
        }
      }
    }
    
    if (items.isEmpty) {
      var rows = document.querySelectorAll('table tbody tr');
      if (rows.isNotEmpty) {
        _parseMateriRows(rows, items);
      }
    }
    
    setState(() {
      _materiList = items;
    });
  }

  void _parseMateriRows(List rows, List<MateriItem> items) {
    for (var row in rows) {
      try {
        final mailboxStar = row.querySelector('td.mailbox-star');
        if (mailboxStar == null) {
          continue;
        }

        final allDivs = mailboxStar.querySelectorAll('div.col-md-4, div.col-md-2');
        if (allDivs.isEmpty) continue;

        final firstDiv = allDivs[0];
        
        final iconElement = firstDiv.querySelector('i');
        
        String type = 'other';
        String icon = 'description';
        String? viewUrl;
        String? downloadUrl;
        String? assignmentUrl;
        String? externalUrl;
        String title = '';
        
        if (iconElement != null) {
          final iconClass = iconElement.className;
          
          if (iconClass.contains('fa-file-pdf')) {
            type = 'pdf';
            icon = 'picture_as_pdf';
            
            final viewLink = firstDiv.querySelector('a[onClick*="lihat_berkas"]');
            if (viewLink != null) {
              final onClick = viewLink.attributes['onClick'] ?? '';
              final match = RegExp(r"lihat_berkas\('([^']+)'\)").firstMatch(onClick);
              if (match != null) {
                viewUrl = match.group(1);
              }
            }
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file-word')) {
            type = 'word';
            icon = 'description';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file-powerpoint')) {
            type = 'powerpoint';
            icon = 'slideshow';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file-excel')) {
            type = 'excel';
            icon = 'table_chart';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file-archive') || iconClass.contains('fa-file-zip')) {
            type = 'archive';
            icon = 'folder_zip';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file-image')) {
            type = 'image';
            icon = 'image';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-file')) {
            type = 'file';
            icon = 'insert_drive_file';
            
            final allLinks = firstDiv.querySelectorAll('a');
            for (var link in allLinks) {
              final href = link.attributes['href'] ?? '';
              if (href.contains('force_download')) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty) {
                  title = linkText;
                }
                final match = RegExp(r'force_download/(.+)$').firstMatch(href);
                if (match != null) {
                  downloadUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-suitcase')) {
            type = 'assignment';
            icon = 'assignment';
            
            final allLinks = firstDiv.querySelectorAll('a[href*="member_tugas"]');
            for (var link in allLinks) {
              final linkText = link.text.trim();
              if (linkText.isNotEmpty) {
                if (linkText.contains(':')) {
                  final parts = linkText.split(':');
                  if (parts.length > 1) {
                    title = parts[1].trim();
                  } else {
                    title = linkText;
                  }
                } else {
                  title = linkText;
                }
                final href = link.attributes['href'] ?? '';
                final match = RegExp(r'member_tugas/kelas/(.+)$').firstMatch(href);
                if (match != null) {
                  assignmentUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-globe')) {
            type = 'url';
            icon = 'link';
            
            final allLinks = firstDiv.querySelectorAll('a[onclick*="display_modal"]');
            for (var link in allLinks) {
              final linkText = link.text.trim();
              if (linkText.isNotEmpty) {
                if (linkText.contains(':')) {
                  final parts = linkText.split(':');
                  if (parts.length > 1) {
                    title = parts[1].trim();
                  } else {
                    title = linkText;
                  }
                } else {
                  title = linkText;
                }
                final onClick = link.attributes['onclick'] ?? link.attributes['onClick'] ?? '';
                final match = RegExp(r"display_modal\('https://lms\.unindra\.ac\.id/member_url/kelas/([^']+)'").firstMatch(onClick);
                if (match != null) {
                  externalUrl = match.group(1);
                }
                break;
              }
            }
            
          } else if (iconClass.contains('fa-comment')) {
            type = 'forum';
            icon = 'forum';
            
            final allLinks = firstDiv.querySelectorAll('a[href*="member_forum"]');
            
            for (var link in allLinks) {
              final linkText = link.text.trim();
              final href = link.attributes['href'] ?? '';
              
              if (linkText.isNotEmpty) {
                if (linkText.contains(':')) {
                  final parts = linkText.split(':');
                  if (parts.length > 1) {
                    title = parts[1].trim();
                  } else {
                    title = linkText;
                  }
                } else {
                  title = linkText;
                }
                final match = RegExp(r'member_forum/kelas/(.+)$').firstMatch(href);
                if (match != null) {
                  externalUrl = match.group(1);
                }
                break;
              }
            }
          } else if (iconClass.contains('fa-video-camera')) {
            type = 'gmeet';
            icon = 'video_call';
            
            final allLinks = firstDiv.querySelectorAll('a[onclick*="display_modal"]');
            
            for (var link in allLinks) {
              final linkText = link.text.trim();
              
              if (linkText.isNotEmpty) {
                if (linkText.toLowerCase().contains('google meet')) {
                  if (linkText.contains(':')) {
                    final parts = linkText.split(':');
                    if (parts.length > 1) {
                      final urlPart = parts.sublist(1).join(':').trim();
                      title = urlPart;
                    } else {
                      title = linkText;
                    }
                  } else {
                    title = linkText;
                  }
                } else {
                  title = linkText;
                }
                
                final onClick = link.attributes['onclick'] ?? link.attributes['onClick'] ?? '';
                final match = RegExp(r"display_modal\('https://lms\.unindra\.ac\.id/member_url/kelas_gmeet/([^']+)'").firstMatch(onClick);
                if (match != null) {
                  externalUrl = match.group(1);
                }
                break;
              }
            }
          } else if (iconClass.contains('fa-youtube')) {
            type = 'youtube';
            icon = 'play_circle';
            
            final allLinks = firstDiv.querySelectorAll('a[onclick*="display_modal"]');
            
            for (var link in allLinks) {
              final linkText = link.text.trim();
              
              if (linkText.isNotEmpty) {
                if (linkText.contains(':')) {
                  final parts = linkText.split(':');
                  if (parts.length > 1) {
                    title = parts[1].trim();
                  } else {
                    title = linkText;
                  }
                } else {
                  title = linkText;
                }
                
                final onClick = link.attributes['onclick'] ?? link.attributes['onClick'] ?? '';
                final match = RegExp(r"display_modal\('https://lms\.unindra\.ac\.id/member_video/kelas_yt/([^']+)'").firstMatch(onClick);
                if (match != null) {
                  externalUrl = match.group(1);
                }
                break;
              }
            }
          }
        }

        String description = '';
        if (allDivs.length > 1) {
          description = allDivs[1].text.trim();
        }

        String date = '';
        if (allDivs.length > 2) {
          date = allDivs[2].text.trim();
        }

        if (title.isNotEmpty || description.isNotEmpty) {
          items.add(MateriItem(
            type: type,
            icon: icon,
            title: title.isEmpty ? description : title,
            description: description,
            url: assignmentUrl ?? externalUrl,
            viewUrl: viewUrl,
            downloadUrl: downloadUrl,
            date: date,
          ));
        }
      } catch (e) {
        print('Error parsing row: $e');
      }
    }
  }

  String _getFileExtension(MateriItem item) {
    if (item.downloadUrl != null) {
      final url = item.downloadUrl!;
      if (url.contains('.')) {
        final ext = url.split('.').last.split('?').first.toLowerCase();
        if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)) {
          return ext;
        }
      }
    }
    
    switch (item.type) {
      case 'pdf':
        return 'pdf';
      case 'word':
        return 'docx';
      case 'powerpoint':
        return 'pptx';
      case 'excel':
        return 'xlsx';
      case 'image':
        return 'jpg';
      case 'archive':
        return 'zip';
      default:
        return 'bin';
    }
  }

  Future<void> _handleFileAction(MateriItem item, {bool download = false}) async {
    if (item.downloadUrl == null) {
      _showSnackBar('URL download tidak ditemukan');
      return;
    }

    bool isGranted = false;
    
    if (await Permission.manageExternalStorage.isGranted) {
      isGranted = true;
    } else if (await Permission.storage.isGranted) {
      isGranted = true;
    } else {
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        isGranted = true;
      } else {
        status = await Permission.storage.request();
        if (status.isGranted) {
          isGranted = true;
        }
      }
    }
    
    if (!isGranted) {
      if (mounted) {
        _showSnackBar('Izin penyimpanan diperlukan untuk download');
      }
      return;
    }

    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Documents');
        if (!await baseDir.exists()) {
          baseDir = Directory('/storage/emulated/0/Download');
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
      
      final mataKuliahFolder = widget.mataKuliah ?? 'Materi';
      final pertemuanFolder = widget.pertemuanKe != null ? 'Pertemuan ${widget.pertemuanKe}' : 'Pertemuan';
      
      final lmsDir = Directory('${baseDir.path}/LMS');
      final mkDir = Directory('${lmsDir.path}/$mataKuliahFolder');
      final pertemuanDir = Directory('${mkDir.path}/$pertemuanFolder');
      
      if (!await lmsDir.exists()) await lmsDir.create(recursive: true);
      if (!await mkDir.exists()) await mkDir.create(recursive: true);
      if (!await pertemuanDir.exists()) await pertemuanDir.create(recursive: true);
      
      final fileExt = _getFileExtension(item);
      String cleanFileName = item.description.isNotEmpty ? item.description : item.title;
      if (cleanFileName.isEmpty) {
        cleanFileName = 'materi_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      cleanFileName = cleanFileName.replaceAll(RegExp(r'^Modul\s+\d+-'), '');
      cleanFileName = cleanFileName.replaceAll(RegExp(r'_\d+$'), '');
      cleanFileName = cleanFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      
      final fileName = '$cleanFileName.$fileExt';
      final savePath = '${pertemuanDir.path}/$fileName';
      final file = File(savePath);
      
      if (await file.exists()) {
        if (download) {
          _showSnackBar('File sudah tersimpan di: Documents/LMS/$mataKuliahFolder/$pertemuanFolder/$fileName');
          return;
        } else {
          final openResult = await OpenFilex.open(savePath);
          if (openResult.type != ResultType.done) {
            _showSnackBar('File ada tetapi tidak dapat dibuka. Silakan buka manual.');
          }
          return;
        }
      }

      final fileTypeName = _getFileTypeName(item.type);
      
      final progressNotifier = ValueNotifier<double>(0.0);
      final receivedNotifier = ValueNotifier<int>(0);
      final totalNotifier = ValueNotifier<int>(0);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              return ValueListenableBuilder<int>(
                valueListenable: receivedNotifier,
                builder: (context, received, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: totalNotifier,
                    builder: (context, total, _) {
                      return AlertDialog(
                        title: Text('Mengunduh $fileTypeName'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 16),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (total > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(received / 1024 / 1024).toStringAsFixed(2)} MB / ${(total / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      }
      
      final result = await _apiService.downloadFile(
        item.downloadUrl!, 
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            receivedNotifier.value = received;
            totalNotifier.value = total;
          }
        },
      );

      // Cleanup ValueNotifiers
      progressNotifier.dispose();
      receivedNotifier.dispose();
      totalNotifier.dispose();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result != null) {
        if (download) {
          _showSnackBar('File disimpan di: Documents/LMS/$mataKuliahFolder/$pertemuanFolder/$fileName');
        } else {
          final openResult = await OpenFilex.open(savePath);
          if (openResult.type != ResultType.done) {
            _showSnackBar('File diunduh tetapi tidak dapat dibuka. Silakan buka manual.');
          }
        }
      } else {
        _showSnackBar('Gagal mengunduh file');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnackBar('Error: $e');
    }
  }

  String _getFileTypeName(String type) {
    switch (type) {
      case 'pdf':
        return 'PDF';
      case 'word':
        return 'Word';
      case 'powerpoint':
        return 'PowerPoint';
      case 'excel':
        return 'Excel';
      case 'image':
        return 'Gambar';
      case 'archive':
        return 'Arsip';
      default:
        return 'File';
    }
  }

  Future<void> _handleUrlAction(MateriItem item) async {
    if (item.url == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengambil URL eksternal...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final realUrl = await _apiService.fetchExternalUrl(item.url!);
      
      if (mounted) Navigator.pop(context);
      
      if (realUrl != null && realUrl.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(item.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.isNotEmpty) ...[
                    Text(item.description),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            realUrl,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse(realUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      _showSnackBar('Tidak dapat membuka URL');
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Buka di Browser'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackBar('URL eksternal tidak ditemukan');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showSnackBar('Error mengambil URL: $e');
      }
    }
  }

  Future<void> _handleForumAction(MateriItem item) async {
    if (item.url == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumScreen(
          encryptedUrl: item.url!,
          title: item.title,
        ),
      ),
    );
  }

  Future<void> _handleGoogleMeetAction(MateriItem item) async {
    if (item.url == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengambil link Google Meet...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final realUrl = await _apiService.fetchGoogleMeetUrl(item.url!);
      
      if (mounted) Navigator.pop(context);
      
      if (realUrl != null && realUrl.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.video_call, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Google Meet')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.isNotEmpty) ...[
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            realUrl,
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 13,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse(realUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      _showSnackBar('Tidak dapat membuka Google Meet');
                    }
                  },
                  icon: const Icon(Icons.video_call),
                  label: const Text('Buka Google Meet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackBar('Link Google Meet tidak ditemukan');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showSnackBar('Error mengambil link Google Meet: $e');
      }
    }
  }

  Future<void> _handleYouTubeAction(MateriItem item) async {
    if (item.url == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengambil link YouTube...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final realUrl = await _apiService.fetchYouTubeUrl(item.url!);
      
      if (mounted) Navigator.pop(context);
      
      if (realUrl != null && realUrl.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.play_circle, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('YouTube Video')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.isNotEmpty) ...[
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            realUrl,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse(realUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      _showSnackBar('Tidak dapat membuka YouTube');
                    }
                  },
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Buka YouTube'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackBar('Link YouTube tidak ditemukan');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showSnackBar('Error mengambil link YouTube: $e');
      }
    }
  }

  Future<void> _handleAssignmentAction(MateriItem item) async {
    if (item.url == null) {
      _showSnackBar('URL assignment tidak ditemukan');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentScreen(
          encryptedUrl: item.url!,
          title: item.title,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'picture_as_pdf':
        return Icons.picture_as_pdf;
      case 'description':
        return Icons.description;
      case 'slideshow':
        return Icons.slideshow;
      case 'table_chart':
        return Icons.table_chart;
      case 'folder_zip':
        return Icons.folder_zip;
      case 'image':
        return Icons.image;
      case 'insert_drive_file':
        return Icons.insert_drive_file;
      case 'assignment':
        return Icons.assignment;
      case 'link':
        return Icons.link;
      case 'forum':
        return Icons.forum;
      case 'video_call':
        return Icons.video_call;
      case 'play_circle':
        return Icons.play_circle;
      default:
        return Icons.description;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'word':
        return Colors.blue.shade700;
      case 'powerpoint':
        return Colors.orange.shade700;
      case 'excel':
        return Colors.green.shade700;
      case 'image':
        return Colors.purple;
      case 'archive':
        return Colors.amber.shade700;
      case 'file':
        return Colors.blueGrey;
      case 'assignment':
        return Colors.blue;
      case 'url':
        return Colors.green;
      case 'forum':
        return Colors.deepPurple;
      case 'gmeet':
        return Colors.green.shade600;
      case 'youtube':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title ?? 
                        widget.namaMataKuliah ?? 
                        widget.mataKuliah ?? 
                        'Pertemuan';
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 40,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF073163),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 0, bottom: 15),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF073163), Color(0xFF1756a5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _materiList.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Tidak ada materi',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _materiList[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          if (item.type == 'assignment') {
                            _handleAssignmentAction(item);
                          } else if (item.type == 'url') {
                            _handleUrlAction(item);
                          } else if (item.type == 'forum') {
                            _handleForumAction(item);
                          } else if (item.type == 'gmeet') {
                            _handleGoogleMeetAction(item);
                          } else if (item.type == 'youtube') {
                            _handleYouTubeAction(item);
                          } else if (item.downloadUrl != null) {
                            _handleFileAction(item);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getIconColor(item.type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getIconData(item.icon),
                                      color: _getIconColor(item.type),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (item.date.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.date,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (item.downloadUrl != null && 
                                  (item.type == 'pdf' || item.type == 'word' || 
                                   item.type == 'powerpoint' || item.type == 'excel' || 
                                   item.type == 'image' || item.type == 'archive' || 
                                   item.type == 'file')) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _handleFileAction(item),
                                        icon: const Icon(Icons.visibility, size: 18),
                                        label: const Text('Buka'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _getIconColor(item.type),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _handleFileAction(item, download: true),
                                        icon: const Icon(Icons.download, size: 18),
                                        label: const Text('Download'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _getIconColor(item.type),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _materiList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
