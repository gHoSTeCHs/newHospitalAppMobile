import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hospital_app/models/message_file.dart';
import 'package:hospital_app/models/message_status.dart';
import 'package:hospital_app/services/auth_service.dart';
import 'package:hospital_app/services/message_service.dart';
// import 'package:hospital_app/utils/boxstyling.dart';
import 'package:hospital_app/utils/file_methods.dart';
import 'package:hospital_app/models/message.dart';
import 'package:hospital_app/utils/formatters.dart';
import 'package:hospital_app/config/app_config.dart';
import 'package:uuid/uuid.dart';

class TestScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String avatarUrl;
  final bool isOnline;

  const TestScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
  });

  @override
  State<TestScreen> createState() => _ChatDScreenState();
}

class _ChatDScreenState extends State<TestScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessageService _messageService = MessageService();
  final _uuid = Uuid();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _hasNetworkConnection = true;
  final int _currentPageSize = AppConfig.defaultPageSize;
  int _currentOffset = 0;
  bool _hasMoreMessages = true;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _messageSubscription;
  int? _currentUserId;

  List<PlatformFile> _selectedFiles = [];
  final Map<String, bool> _fileUploadProgress = {};

  bool _isAlert = false;
  bool _isEmergency = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
      _refreshMessages();
    }
  }

  Future<void> _initializeChat() async {
    await _getCurrentUserId();
    await _checkConnectivity();
    await _fetchMessages();
    _setupMessageListener();
    _setupScrollListener();
    _setupConnectivityListener();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      } else {
        _showErrorSnackbar('Unable to identify current user');
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
      _showErrorSnackbar('Authentication error');
      Navigator.of(context).pop();
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _hasNetworkConnection = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      setState(() {
        _hasNetworkConnection = false;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final hasConnection = result != ConnectivityResult.none;

      if (hasConnection && !_hasNetworkConnection) {
        // Connection restored - refresh messages
        _refreshMessages();
      }

      setState(() {
        _hasNetworkConnection = hasConnection;
      });
    });
  }

  void _setupMessageListener() {
    if (AppConfig.enablePushNotifications) {
      // Ideally replace polling with a proper subscription
      // This is a fallback for now
      _messageSubscription = Stream.periodic(
        Duration(milliseconds: AppConfig.messageRefreshInterval),
      ).listen((_) {
        if (_hasNetworkConnection && !_isSending) {
          _refreshMessages();
        }
      });
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreMessages &&
          _hasNetworkConnection) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _pickFiles() async {
    if (_isSending) return;

    try {
      // Define allowed file types and max sizes
      final maxFileSize = 10 * 1024 * 1024; // 10MB

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null) {
        // Filter out files that exceed size limit
        final validFiles =
            result.files.where((file) => file.size <= maxFileSize).toList();
        final oversizedFiles =
            result.files.where((file) => file.size > maxFileSize).toList();

        if (oversizedFiles.isNotEmpty) {
          _showErrorSnackbar(
            '${oversizedFiles.length} files exceeded the 10MB limit and were not added',
          );
        }

        setState(() {
          _selectedFiles = validFiles;
          // Initialize upload progress tracking
          for (var file in _selectedFiles) {
            _fileUploadProgress[file.name] = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
      _showErrorSnackbar('Failed to select files');
    }
  }

  Future<void> _fetchMessages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!_hasNetworkConnection) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final messages = await _messageService.getMessages(
        // Renamed from gM
        widget.chatId,
        limit: _currentPageSize,
        offset: _currentOffset,
      );

      setState(() {
        _messages = messages;
        _isLoading = false;
        _hasMoreMessages = messages.length == _currentPageSize;
      });
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackbar('Failed to load messages');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextOffset = _currentOffset + _currentPageSize;

      final olderMessages = await _messageService.getMessages(
        widget.chatId,
        limit: _currentPageSize,
        offset: nextOffset,
      );

      if (olderMessages.isNotEmpty) {
        // Filter to avoid duplicates
        final newMessages =
            olderMessages
                .where(
                  (newMsg) =>
                      !_messages.any(
                        (existingMsg) => existingMsg.id == newMsg.id,
                      ),
                )
                .toList();

        if (mounted) {
          setState(() {
            _messages = [..._messages, ...newMessages];
            _currentOffset = nextOffset;
            _hasMoreMessages = olderMessages.length == _currentPageSize;
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMoreMessages = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showErrorSnackbar('Failed to load older messages');
      }
    }
  }

  Future<void> _refreshMessages() async {
    if (_isLoading || _isSending || !_hasNetworkConnection) return;

    try {
      final latestMessages = await _messageService.getMessages(
        widget.chatId,
        limit: 10, // Just get the latest 10 messages
        offset: 0,
      );

      // Calculate previous scroll position to maintain it after refresh
      final previousScrollOffset = _scrollController.position.pixels;
      final wasAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;

      // Filter for truly new messages to avoid duplicates
      final newMessages =
          latestMessages
              .where(
                (newMsg) =>
                    !_messages.any(
                      (existingMsg) => existingMsg.id == newMsg.id,
                    ),
              )
              .toList();

      if (newMessages.isNotEmpty && mounted) {
        setState(() {
          _messages = [...newMessages, ..._messages];
        });

        // Restore scroll position unless user was at bottom
        if (!wasAtBottom) {
          // Wait for layout to complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                previousScrollOffset + _calculateNewContentHeight(newMessages),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing messages: $e');
      // No need to show error for background refresh
    }
  }

  double _calculateNewContentHeight(List<Message> newMessages) {
    // Rough estimate of new content height
    // In a real app, you might need to measure actual rendered heights
    const estimatedMessageHeight = 100.0;
    return newMessages.length * estimatedMessageHeight;
  }

  void _toggleAlert() {
    setState(() {
      _isAlert = !_isAlert;
    });
  }

  void _toggleEmergency() {
    setState(() {
      _isEmergency = !_isEmergency;
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if ((messageText.isEmpty && _selectedFiles.isEmpty) ||
        _isSending ||
        !_hasNetworkConnection) {
      if (!_hasNetworkConnection) {
        _showErrorSnackbar(
          'No internet connection. Please try again when online.',
        );
      }
      return;
    }

    _messageController.clear();
    setState(() {
      _isSending = true;
    });

    if (_selectedFiles.isNotEmpty) {
      await _sendMessageWithFiles(messageText);
    } else {
      await _sendTextMessage(messageText);
    }
  }

  Future<void> _sendMessageWithFiles(String messageText) async {
    // Generate a unique ID that won't collide
    final tempId = _uuid.v4();

    // Save tag states and reset them
    bool wasAlert = _isAlert;
    bool wasEmergency = _isEmergency;

    setState(() {
      _isAlert = false;
      _isEmergency = false;
    });

    // Create file metadata
    List<MessageFile> tempFiles =
        _selectedFiles.map((file) {
          final fileName = file.path?.split('/').last ?? 'unnamed_file';
          // Sanitize the file name
          final sanitizedFileName = fileName.replaceAll(
            RegExp(r'[^\w\s\.\-]'),
            '_',
          );

          return MessageFile(
            id: int.parse(_uuid.v4()),
            messageId: int.parse(tempId),
            filePath: file.path,
            fileName: sanitizedFileName,
            fileSize: file.size,
            mimeType: FileMethods.getMimeType(sanitizedFileName),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();

    // Create optimistic message
    final optimisticMessage = Message(
      id: int.parse(tempId),
      conversationId: widget.chatId,
      senderId: _currentUserId ?? 0,
      content: messageText,
      createdAt: DateTime.now(),
      readAt: null,
      files: tempFiles,
      messageType: _selectedFiles.length > 1 ? 'files' : 'file',
      isAlert: wasAlert,
      isEmergency: wasEmergency,
      updatedAt: DateTime.now(),
      status: [
        MessageStatus(
          id: 0, // Use appropriate ID or generate one
          messageId: int.parse(tempId),
          userId: _currentUserId ?? 0,
          status: 'sending',
          createdAt: DateTime.now(),
        ),
      ],
    );

    // Add optimistic message
    setState(() {
      _messages.insert(0, optimisticMessage);
      for (var file in _selectedFiles) {
        _fileUploadProgress[file.name] = true;
      }
    });

    try {
      // Attempt to send files
      final sentMessage = await _messageService.sendFiles(
        // Renamed from sendfile
        _selectedFiles,
        widget.chatId,
        messageText, // Pass the text content as well
        wasAlert,
        wasEmergency,
        onProgress: (fileName, progress) {
          // Update file upload progress
          if (mounted) {
            setState(() {
              _fileUploadProgress[fileName] = progress >= 1.0;
            });
          }
        },
      );

      if (sentMessage != null && mounted) {
        // Replace optimistic message with actual message
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = sentMessage;
          } else {
            _messages.insert(0, sentMessage);
          }
          _selectedFiles.clear();
          _fileUploadProgress.clear();
          _isSending = false;
        });
      } else if (mounted) {
        // Handle send failure
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Create a new MessageStatus object with 'failed' status
            MessageStatus failedStatus = MessageStatus(
              id: 0, // Use an appropriate ID or generate one
              messageId: _messages[index].id,
              userId:
                  _messages[index].senderId, // Or use the appropriate user ID
              status: 'failed',
              createdAt: DateTime.now(),
            );

            // Use copyWith to update the message with the new status
            _messages[index] = _messages[index].copyWith(
              status: [
                failedStatus,
              ], // Or append to existing status list if needed
            );
          }
          _isSending = false;
        });
        _showErrorSnackbar('Failed to send files');
      }
    } catch (e) {
      debugPrint("Error sending file $e");
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Create a new MessageStatus object with 'failed' status
            MessageStatus failedStatus = MessageStatus(
              id: 0, // Use an appropriate ID or generate one
              messageId: _messages[index].id,
              userId:
                  _messages[index].senderId, // Or use the appropriate user ID
              status: 'failed',
              createdAt: DateTime.now(),
            );

            // Use copyWith to update the message with the new status
            _messages[index] = _messages[index].copyWith(
              status: [
                failedStatus,
              ], // Or append to existing status list if needed
            );
          }
          _isSending = false;
        });
        _showErrorSnackbar('Network error. Could not upload files.');
      }
    }
  }

  Future<void> _sendTextMessage(String messageText) async {
    // Generate a unique ID that won't collide
    final tempId = _uuid.v4();

    // Save tag states and reset them
    bool wasAlert = _isAlert;
    bool wasEmergency = _isEmergency;

    setState(() {
      _isAlert = false;
      _isEmergency = false;
    });

    // Create optimistic message
    final optimisticMessage = Message(
      id: int.parse(tempId),
      conversationId: widget.chatId,
      senderId: _currentUserId ?? 0,
      content: messageText,
      createdAt: DateTime.now(),
      readAt: null,
      files: [],
      messageType: 'text',
      isAlert: wasAlert,
      isEmergency: wasEmergency,
      updatedAt: DateTime.now(),
      status: [
        MessageStatus(
          id: 0, // Use appropriate ID or generate one
          messageId: int.parse(tempId),
          userId: _currentUserId ?? 0,
          status: 'sending',
          createdAt: DateTime.now(),
        ),
      ],
    );

    // Add optimistic message
    setState(() {
      _messages.insert(0, optimisticMessage);
    });

    try {
      // Attempt to send message
      final sentMessage = await _messageService.sendMessage(
        // Renamed from pasteMessages
        widget.chatId,
        'text',
        // [],
        // messageText,
        // wasAlert,
        // wasEmergency,
      );

      if (sentMessage != null && mounted) {
        // Replace optimistic message with actual message
        setState(() {
          final index = _messages.indexWhere((m) => m.id == int.parse(tempId));
          if (index != -1) {
            _messages[index] = sentMessage;
          } else {
            _messages.insert(0, sentMessage);
          }
          _isSending = false;
        });
      } else if (mounted) {
        // Handle send failure
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Create a new MessageStatus object with 'failed' status
            MessageStatus failedStatus = MessageStatus(
              id: 0, // Use an appropriate ID or generate one
              messageId: _messages[index].id,
              userId:
                  _messages[index].senderId, // Or use the appropriate user ID
              status: 'failed',
              createdAt: DateTime.now(),
            );

            // Use copyWith to update the message with the new status
            _messages[index] = _messages[index].copyWith(
              status: [
                failedStatus,
              ], // Or append to existing status list if needed
            );
          }
          _isSending = false;
        });
        _showErrorSnackbar('Failed to send message');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Create a new MessageStatus object with 'failed' status
            MessageStatus failedStatus = MessageStatus(
              id: 0, // Use an appropriate ID or generate one
              messageId: _messages[index].id,
              userId:
                  _messages[index].senderId, // Or use the appropriate user ID
              status: 'failed',
              createdAt: DateTime.now(),
            );

            // Use copyWith to update the message with the new status
            _messages[index] = _messages[index].copyWith(
              status: [
                failedStatus,
              ], // Or append to existing status list if needed
            );
          }
          _isSending = false;
        });
        _showErrorSnackbar('Network error. Please try again.');
      }
    }
  }

  // Add retry functionality for failed messages
  Future<void> _retryMessage(Message failedMessage) async {
    if (!_hasNetworkConnection) {
      _showErrorSnackbar(
        'No internet connection. Please try again when online.',
      );
      return;
    }

    // Update status to retrying
    setState(() {
      final index = _messages.indexWhere((m) => m.id == failedMessage.id);
      if (index != -1) {
        // Create a new MessageStatus object with 'retrying' status
        MessageStatus retryingStatus = MessageStatus(
          id: 0, // Use an appropriate ID or generate one
          messageId: _messages[index].id,
          userId: _messages[index].senderId, // Or use the appropriate user ID
          status: 'retrying',
          createdAt: DateTime.now(),
        );

        // Use copyWith to update the message with the new status
        _messages[index] = _messages[index].copyWith(
          status: [
            retryingStatus,
          ], // Or append to existing status list if needed
        );
      }
      _isSending = true;
    });

    // Determine if this is a file message or text message
    if (failedMessage.files.isNotEmpty) {
      try {
        // We need to handle file retry differently since we need the actual files
        // In a real app, you'd store file paths or have a way to access them
        _showErrorSnackbar('Please reselect files to retry sending');
        setState(() {
          _isSending = false;
          // Remove the failed message
          _messages.removeWhere((m) => m.id == failedMessage.id);
        });
      } catch (e) {
        debugPrint('Error retrying file message: $e');
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == failedMessage.id);
            if (index != -1) {
              // Create a new MessageStatus object with 'failed' status
              MessageStatus failedStatus = MessageStatus(
                id: 0, // Use an appropriate ID or generate one
                messageId: _messages[index].id,
                userId:
                    _messages[index].senderId, // Or use the appropriate user ID
                status: 'failed',
                createdAt: DateTime.now(),
              );

              // Use copyWith to update the message with the new status
              _messages[index] = _messages[index].copyWith(
                status: [
                  failedStatus,
                ], // Or append to existing status list if needed
              );
            }
            _isSending = false;
          });
          _showErrorSnackbar('Failed to retry message');
        }
      }
    } else {
      // Retry text message
      try {
        final sentMessage = await _messageService.sendMessage(
          widget.chatId,
          'text',
          // [],
          // failedMessage.content ?? '',
          // failedMessage.isAlert,
          // failedMessage.isEmergency,
        );

        if (sentMessage != null && mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == failedMessage.id);
            if (index != -1) {
              _messages[index] = sentMessage;
            } else {
              _messages.insert(0, sentMessage);
            }
            _isSending = false;
          });
        } else if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == failedMessage.id);
            if (index != -1) {
              // Create a new MessageStatus object with 'failed' status
              MessageStatus failedStatus = MessageStatus(
                id: 0, // Use an appropriate ID or generate one
                messageId: _messages[index].id,
                userId:
                    _messages[index].senderId, // Or use the appropriate user ID
                status: 'failed',
                createdAt: DateTime.now(),
              );

              // Use copyWith to update the message with the new status
              _messages[index] = _messages[index].copyWith(
                status: [
                  failedStatus,
                ], // Or append to existing status list if needed
              );
            }
            _isSending = false;
          });
          _showErrorSnackbar('Failed to retry message');
        }
      } catch (e) {
        debugPrint('Error retrying message: $e');
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == failedMessage.id);
            if (index != -1) {
              // Create a new MessageStatus object with 'failed' status
              MessageStatus failedStatus = MessageStatus(
                id: 0, // Use an appropriate ID or generate one
                messageId: _messages[index].id,
                userId:
                    _messages[index].senderId, // Or use the appropriate user ID
                status: 'failed',
                createdAt: DateTime.now(),
              );

              // Use copyWith to update the message with the new status
              _messages[index] = _messages[index].copyWith(
                status: [
                  failedStatus,
                ], // Or append to existing status list if needed
              );
            }
            _isSending = false;
          });
          _showErrorSnackbar('Network error. Please try again.');
        }
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action:
            message.contains('internet') || message.contains('network')
                ? SnackBarAction(label: 'Retry', onPressed: _checkConnectivity)
                : null,
      ),
    );
  }

  void _onEmojiSelected(Emoji emoji) {
    // Get current cursor position
    final cursorPos = _messageController.selection.base.offset;

    // If cursor position is valid
    if (cursorPos >= 0) {
      final text = _messageController.text;
      final newText =
          text.substring(0, cursorPos) +
          emoji.emoji +
          text.substring(cursorPos);

      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + emoji.emoji.length,
        ),
      );
    } else {
      // Just append if no valid cursor position
      _messageController.text = _messageController.text + emoji.emoji;
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _connectivitySubscription?.cancel();
    _messageSubscription?.cancel();
    _selectedFiles.clear();
    _fileUploadProgress.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          // semanticLabel: 'Go back',
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.avatarUrl),
                ),
                if (widget.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.indigo),
            onPressed: () {},
            tooltip: 'Video call',

            // semanticLabel: 'Start video call',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
            tooltip: 'More options',
            // semanticLabel: 'Show more options',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Network connectivity banner
            if (!_hasNetworkConnection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    Icon(
                      Icons.signal_wifi_off,
                      color: Colors.red.shade800,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet connection',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    TextButton(
                      onPressed: _checkConnectivity,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            // Messages list
            Expanded(
              child:
                  _isLoading && _messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _buildMessagesList(),
            ),

            // Message tag controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Alert tag toggle
                  FilterChip(
                    label: const Text('Alert'),
                    selected: _isAlert,
                    selectedColor: Colors.amber.shade200,
                    avatar: Icon(
                      Icons.notifications_active,
                      color: _isAlert ? Colors.amber.shade800 : Colors.grey,
                      size: 16,
                    ),
                    onSelected: (_) => _toggleAlert(),
                    tooltip: 'Mark as alert',
                  ),
                  const SizedBox(width: 8),
                  // Emergency tag toggle
                  FilterChip(
                    label: const Text('Emergency'),
                    selected: _isEmergency,
                    selectedColor: Colors.red.shade100,
                    avatar: Icon(
                      Icons.warning_rounded,
                      color: _isEmergency ? Colors.red : Colors.grey,
                      size: 16,
                    ),
                    onSelected: (_) => _toggleEmergency(),
                    tooltip: 'Mark as emergency',
                  ),
                ],
              ),
            ),

            // Message input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    spreadRadius: 1,
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFilePreview(),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: _toggleEmojiPicker,
                        tooltip: 'Insert emoji',
                        // semanticLabel: 'Insert emoji',
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        onPressed: _pickFiles,
                        tooltip: 'Attach file',
                        // semanticLabel: 'Attach file',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: "Write a message...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          enabled: !_isSending,
                        ),
                      ),
                      _buildSendButton(),
                    ],
                  ),
                ],
              ),
            ),

            // Emoji picker
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                  config: Config(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return FloatingActionButton(
      onPressed: _isSending ? null : _sendMessage,
      mini: true,
      backgroundColor:
          _isSending ? Colors.grey : Theme.of(context).primaryColor,
      tooltip: 'Send message',
      // semanticLabel: 'Send message',
      child:
          _isSending
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Icon(Icons.send),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount:
          _messages.length +
          (_isLoadingMore ? 1 : 0) +
          (_hasMoreMessages && !_isLoadingMore ? 1 : 0),
      reverse: true,
      itemBuilder: (context, index) {
        // Show loading indicator at the end when loading more messages
        if (_isLoadingMore && index == _messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show "Load More" button at the end if there are more messages
        // Show "Load More" button at the end if there are more messages
        if (!_isLoadingMore && _hasMoreMessages && index == _messages.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: TextButton.icon(
                onPressed: _loadMoreMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Load more messages'),
              ),
            ),
          );
        }

        // Regular message item
        final message = _messages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildFilePreview() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedFiles.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final isUploading = _fileUploadProgress[file.name] ?? false;

              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getFileIcon(file.name),
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.name.length > 10
                              ? '${file.name.substring(0, 10)}...'
                              : file.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap:
                          isUploading
                              ? null
                              : () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                  _fileUploadProgress.remove(file.name);
                                });
                              },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_selectedFiles.length > 1)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedFiles.clear();
                    _fileUploadProgress.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: Colors.red.shade700,
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildMessageItem(Message message) {
    final bool isMe = message.senderId == _currentUserId;
    final bool isFailedMessage = (message.status).contains('failed');
    final bool isSendingMessage =
        (message.status).contains('sending') ||
        (message.status).contains('retrying');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 16,
          left: isMe ? 80 : 0,
          right: isMe ? 0 : 80,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender info for non-user messages
            if (!isMe)
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(widget.avatarUrl),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),

            // Message status indicators (Alert/Emergency)
            if (message.isAlert || message.isEmergency)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isAlert)
                      _buildTagBadge(
                        'Alert',
                        Icons.notifications_active,
                        Colors.amber,
                      ),
                    if (message.isAlert && message.isEmergency)
                      const SizedBox(width: 4),
                    if (message.isEmergency)
                      _buildTagBadge(
                        'Emergency',
                        Icons.warning_rounded,
                        Colors.red,
                      ),
                  ],
                ),
              ),

            // Message content
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getMessageBackgroundColor(message, isMe),
                borderRadius: BorderRadius.circular(16),
                border: _getMessageBorder(message, isFailedMessage),
                boxShadow: [
                  BoxShadow(
                    color: _getMessageShadowColor(
                      message,
                      isMe,
                      isFailedMessage,
                    ),
                    spreadRadius: message.isEmergency ? 2 : 1,
                    blurRadius: message.isEmergency ? 3 : 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File type indicator for file messages
                  if (message.files.isNotEmpty) _buildFileTypeBadge(message),

                  // File attachments preview
                  if (message.files.isNotEmpty) _buildFileAttachments(message),

                  // Message text
                  if ((message.content ?? '').isNotEmpty)
                    Text(
                      message.content ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),

            // Timestamp, message status and retry option
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (isMe && !isFailedMessage)
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(
                          message.readAt != null ? Icons.done_all : Icons.done,
                          size: 14,
                          color:
                              message.readAt != null
                                  ? Colors.blue
                                  : Colors.grey.shade600,
                        ),
                      ],
                    ),
                  if (isFailedMessage)
                    TextButton(
                      onPressed: () => _retryMessage(message),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: TextStyle(fontSize: 11, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  if (isSendingMessage)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagBadge(String label, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade800),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTypeBadge(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            message.files.length > 1
                ? Icons.folder
                : _getFileIconFromMimeType(message.files.first.mimeType ?? ''),
            size: 12,
            color: Colors.black54,
          ),
          const SizedBox(width: 4),
          Text(
            message.files.length > 1
                ? '${message.files.length} Files'
                : _getFileTypeLabel(message.files.first.mimeType ?? ''),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachments(Message message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          message.files.map((file) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFileIconFromMimeType(file.mimeType ?? ''),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName ?? 'Unknown File',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatFileSize(file.fileSize),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Color _getMessageBackgroundColor(Message message, bool isMe) {
    if (message.isEmergency) {
      return isMe ? Colors.red.shade600 : Colors.red.shade50;
    }
    if (message.isAlert) {
      return isMe ? Colors.amber.shade600 : Colors.amber.shade50;
    }
    return isMe ? Theme.of(context).primaryColor : Colors.grey.shade100;
  }

  BoxBorder? _getMessageBorder(Message message, bool isFailedMessage) {
    if (isFailedMessage) {
      return Border.all(color: Colors.red.shade300, width: 1.5);
    }
    if (message.isEmergency) {
      return Border.all(color: Colors.red.shade300);
    }
    if (message.isAlert) {
      return Border.all(color: Colors.amber.shade300);
    }
    return null;
  }

  Color _getMessageShadowColor(
    Message message,
    bool isMe,
    bool isFailedMessage,
  ) {
    if (isFailedMessage) {
      return Colors.red.withOpacity(0.3);
    }
    if (message.isEmergency) {
      return Colors.red.withOpacity(0.3);
    }
    if (message.isAlert) {
      return Colors.amber.withOpacity(0.3);
    }
    return Colors.grey.withOpacity(0.1);
  }

  IconData _getFileIconFromMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.startsWith('video/')) {
      return Icons.videocam;
    } else if (mimeType.startsWith('audio/')) {
      return Icons.audiotrack;
    } else if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') ||
        mimeType.contains('document') ||
        mimeType == 'application/rtf') {
      return Icons.description;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    } else {
      return Icons.insert_drive_file;
    }
  }

  String _getFileTypeLabel(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return 'Image';
    } else if (mimeType.startsWith('video/')) {
      return 'Video';
    } else if (mimeType.startsWith('audio/')) {
      return 'Audio';
    } else if (mimeType == 'application/pdf') {
      return 'PDF';
    } else if (mimeType.contains('word') ||
        mimeType.contains('document') ||
        mimeType == 'application/rtf') {
      return 'Document';
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return 'Spreadsheet';
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return 'Presentation';
    } else {
      return 'File';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    return DateFormatter.formatMessageTime(dateTime);
  }
}
