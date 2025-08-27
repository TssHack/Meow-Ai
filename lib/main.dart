import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/gestures.dart';

void main() {
  runApp(MeowAIApp());
}

class MeowAIApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meow AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey[700]!,
          surface: Colors.white,
          background: Colors.grey[50]!,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'SF Pro Display',
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'SF Pro Display',
            color: Colors.grey[600],
          ),
          headlineSmall: TextStyle(
            fontFamily: 'SF Pro Display',
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: ChatScreen(),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? messageId;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageId,
  });
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isDarkMode = false;
  late AnimationController _typingController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _loadWelcomeMessages();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _fadeController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadWelcomeMessages() {
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _messages.add(
          Message(
            text:
                '👋 سلام! من Meow AI هستم، دستیار هوش مصنوعی شما.\n\nچه کاری می‌تونم برای شما انجام بدم؟',
            isUser: false,
            timestamp: DateTime.now(),
            messageId: 'welcome_1',
          ),
        );
      });
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add(
        Message(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
          messageId: messageId,
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();
    _unfocus();

    try {
      final userId = Random().nextInt(999999).toString();
      final encodedQuery = Uri.encodeComponent(message);
      final url =
          'https://api.ehsanjs.ir/meow.php?query=$encodedQuery&user_id=$userId';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'MeowAI/1.0', 'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse =
            data['result']['formatted_text'] ?? 'متاسفم، پاسخی دریافت نکردم.';

        // Simulate typing delay
        await Future.delayed(Duration(milliseconds: 800));

        setState(() {
          _messages.add(
            Message(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
              messageId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
            ),
          );
        });
      } else {
        _addErrorMessage(
          'خطا در برقراری ارتباط با سرور (کد: ${response.statusCode})',
        );
      }
    } catch (e) {
      _addErrorMessage('متاسفم، مشکلی پیش اومده. لطفاً دوباره تلاش کنید.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _addErrorMessage(String errorText) {
    setState(() {
      _messages.add(
        Message(
          text: errorText,
          isUser: false,
          timestamp: DateTime.now(),
          messageId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _unfocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _clearChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Icon(Icons.delete_sweep_rounded, size: 48, color: Colors.red[400]),
            SizedBox(height: 16),
            Text(
              'پاک کردن تاریخچه چت',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'آیا مطمئنید که می‌خواهید تمام پیام‌ها را پاک کنید؟ این عمل قابل بازگشت نیست.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'انصراف',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                      });
                      Navigator.pop(context);
                      _loadWelcomeMessages();
                      _showSnackBar(
                        'تاریخچه چت پاک شد',
                        Icons.check_circle_rounded,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'پاک کردن',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'تنظیمات',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 24),
            _buildSettingItem(
              icon: _isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: 'حالت شب',
              subtitle: 'تغییر ظاهر برنامه',
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  Navigator.pop(context);
                },
                activeColor: Colors.black,
              ),
            ),
            _buildSettingItem(
              icon: Icons.info_rounded,
              title: 'درباره برنامه',
              subtitle: 'Meow AI v2.0 - احسان فضلی',
              onTap: _showAbout,
            ),
            _buildSettingItem(
              icon: Icons.share_rounded,
              title: 'اشتراک‌گذاری',
              subtitle: 'معرفی برنامه به دوستان',
              onTap: () {
                Share.share(
                  'سلام! از برنامه Meow AI استفاده کن - یک دستیار هوش مصنوعی فوق‌العاده!',
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showAbout() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[800]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text('Meow AI', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('نسخه', '2.0.0'),
            _buildInfoRow('توسعه‌دهنده', 'احسان فضلی'),
            _buildInfoRow('پلتفرم', 'Flutter'),
            _buildInfoRow('تاریخ انتشار', '2024'),
            SizedBox(height: 16),
            Text(
              'یک دستیار هوش مصنوعی پیشرفته با رابط کاربری مدرن و قابلیت‌های گسترده برای پاسخگویی به سوالات شما.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'بستن',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('نمی‌توان لینک را باز کرد', Icons.error_rounded);
      }
    } catch (e) {
      _showSnackBar('خطا در باز کردن لینک', Icons.error_rounded);
    }
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('پیام کپی شد', Icons.copy_rounded);
  }

  void _shareMessage(String text) {
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.grey[50],
      body: GestureDetector(
        onTap: _unfocus,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcomeScreen()
                  : _buildMessagesList(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _clearChat,
            icon: Icon(
              Icons.refresh_rounded,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[100],
              padding: EdgeInsets.all(12),
            ),
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.grey[800]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Meow AI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _isDarkMode ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _showSettings,
            icon: Icon(
              Icons.settings_rounded,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[100],
              padding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 50),
          ),
          SizedBox(height: 24),
          Text(
            'Meow AI',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : Colors.black,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'دستیار هوش مصنوعی شما',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 32),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 32),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFeatureItem(
                  Icons.chat_bubble_outline_rounded,
                  'گفتگوی طبیعی',
                  'با من به صورت طبیعی صحبت کنید',
                ),
                Divider(height: 24),
                _buildFeatureItem(
                  Icons.link_rounded,
                  'باز کردن لینک‌ها',
                  'روی لینک‌های ارسالی کلیک کنید',
                ),
                Divider(height: 24),
                _buildFeatureItem(
                  Icons.copy_rounded,
                  'کپی و اشتراک',
                  'پیام‌ها را کپی یا به اشتراک بگذارید',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.black, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Message message) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            minWidth: 60,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? (_isDarkMode ? Colors.grey[800] : Colors.black)
                : (_isDarkMode ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomRight: message.isUser
                  ? Radius.circular(4)
                  : Radius.circular(18),
              bottomLeft: message.isUser
                  ? Radius.circular(18)
                  : Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: _buildMessageContent(message),
        ),
      ),
    );
  }

  Widget _buildMessageContent(Message message) {
    final urlRegExp = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(message.text);

    if (matches.isEmpty) {
      return Text(
        message.text,
        style: TextStyle(
          color: message.isUser
              ? Colors.white
              : (_isDarkMode ? Colors.white : Colors.black87),
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: message.text.substring(lastMatchEnd, match.start),
            style: TextStyle(
              color: message.isUser
                  ? Colors.white
                  : (_isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(match.group(0)!),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < message.text.length) {
      spans.add(
        TextSpan(
          text: message.text.substring(lastMatchEnd),
          style: TextStyle(
            color: message.isUser
                ? Colors.white
                : (_isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.copy_rounded),
              title: Text('کپی متن'),
              onTap: () {
                _copyMessage(message.text);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_rounded),
              title: Text('اشتراک‌گذاری'),
              onTap: () {
                _shareMessage(message.text);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(
            18,
          ).copyWith(bottomLeft: Radius.circular(4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
              ),
            ),
            SizedBox(width: 12),
            AnimatedBuilder(
              animation: _typingController,
              builder: (context, child) {
                return Text(
                  'در حال تایپ' +
                      '.' * ((_typingController.value * 3).floor() + 1),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? Colors.black.withOpacity(0.2)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'پیام خود را بنویسید...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isLoading ? null : _sendMessage,
                  enabled: !_isLoading,
                ),
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isLoading
                      ? Colors.grey[300]
                      : (_messageController.text.trim().isEmpty
                            ? Colors.grey[300]
                            : Colors.black),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow:
                      _isLoading || _messageController.text.trim().isEmpty
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap:
                        (_isLoading || _messageController.text.trim().isEmpty)
                        ? null
                        : () => _sendMessage(_messageController.text),
                    child: Center(
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[600]!,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _messageController.text.trim().isEmpty
                                  ? Colors.grey[600]
                                  : Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
