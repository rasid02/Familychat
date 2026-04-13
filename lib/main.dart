import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'firebase_options.dart';

const String INVITE_CODE = 'MyFamily';
const String IMGBB_API_KEY = 'd86356bedd46aa3590b59361b2c6f62a';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        scaffoldBackgroundColor: const Color(0xFFECE5DD),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF25D366))));
          }
          if (snapshot.hasData) return const HomeScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final inviteCtrl = TextEditingController();
  String error = '';
  bool loading = false;

  Future<void> submit() async {
    setState(() { loading = true; error = ''; });
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      } else {
        if (inviteCtrl.text.trim() != INVITE_CODE) {
          setState(() { error = 'Неверный инвайт-код!'; loading = false; });
          return;
        }
        if (nameCtrl.text.trim().isEmpty) {
          setState(() { error = 'Введите ваше имя'; loading = false; });
          return;
        }
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        await cred.user!.updateDisplayName(nameCtrl.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'uid': cred.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      setState(() => error = isLogin ? 'Неверный email или пароль' : 'Ошибка регистрации');
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 100,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Center(child: Text('R', style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Color(0xFF075E54)))),
              ),
              const SizedBox(height: 16),
              const Text('FamilyChat', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Семейный мессенджер', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 32),
              if (!isLogin) ...[
                _field(nameCtrl, 'Ваше имя', Icons.person),
                const SizedBox(height: 16),
                _field(inviteCtrl, 'Инвайт-код', Icons.vpn_key),
                const SizedBox(height: 16),
              ],
              _field(emailCtrl, 'Email', Icons.email, type: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field(passCtrl, 'Пароль', Icons.lock, obscure: true),
              const SizedBox(height: 8),
              if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isLogin ? 'ВОЙТИ' : 'ЗАРЕГИСТРИРОВАТЬСЯ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() { isLogin = !isLogin; error = ''; }),
                child: Text(
                  isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool obscure = false, TextInputType? type}) {
    return TextField(
      controller: c, obscureText: obscure, keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF25D366))),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchCtrl = TextEditingController();
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF075E54),
          title: searchQuery.isEmpty
              ? const Text('FamilyChat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              : TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Поиск...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
          actions: [
            IconButton(
              icon: Icon(searchQuery.isEmpty ? Icons.search : Icons.close, color: Colors.white),
              onPressed: () => setState(() { searchQuery = searchQuery.isEmpty ? ' ' : ''; searchCtrl.clear(); }),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) {
                if (v == 'logout') FirebaseAuth.instance.signOut();
                if (v == 'newgroup') _showCreateGroupDialog(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'newgroup', child: Text('Новая группа')),
                const PopupMenuItem(value: 'logout', child: Text('Выйти')),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF25D366),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [Tab(text: 'ЧАТЫ'), Tab(text: 'СТАТУСЫ'), Tab(text: 'ЗВОНКИ')],
          ),
        ),
        body: TabBarView(children: [
          ChatsTab(searchQuery: searchQuery.trim()),
          const StatusTab(),
          const CallsTab(),
        ]),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF25D366),
          onPressed: () => _showNewChatDialog(context),
          child: const Icon(Icons.chat, color: Colors.white),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Создать группу'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название группы')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final user = FirebaseAuth.instance.currentUser!;
              final groupRef = await FirebaseFirestore.instance.collection('groups').add({
                'name': nameCtrl.text.trim(),
                'createdBy': user.uid,
                'members': [user.uid],
                'createdAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatScreen(chatId: groupRef.id, chatName: nameCtrl.text.trim(), isGroup: true)));
            },
            child: const Text('Создать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Новый чат', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF25D366), child: Icon(Icons.people, color: Colors.white)),
            title: const Text('Семейный чат'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ChatScreen(chatId: 'family_chat', chatName: 'Семейный чат', isGroup: true)));
            },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF075E54), child: Icon(Icons.group_add, color: Colors.white)),
            title: const Text('Создать группу'),
            onTap: () { Navigator.pop(context); _showCreateGroupDialog(context); },
          ),
        ]),
      ),
    );
  }
}

class ChatsTab extends StatelessWidget {
  final String searchQuery;
  const ChatsTab({super.key, required this.searchQuery});

  String _getChatId(String uid1, String uid2) =>
      uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return Container(
      color: Colors.white,
      child: ListView(children: [
        if (searchQuery.isEmpty || 'Семейный чат'.toLowerCase().contains(searchQuery.toLowerCase()))
          Column(children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF25D366), child: Icon(Icons.people, color: Colors.white)),
              title: const Text('Семейный чат', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Общий чат для всей семьи'),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ChatScreen(chatId: 'family_chat', chatName: 'Семейный чат', isGroup: true))),
            ),
            const Divider(indent: 72),
          ]),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('groups').where('members', arrayContains: me.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return Column(children: snapshot.data!.docs.map((g) {
              final name = g['name'] as String;
              if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery.toLowerCase())) return const SizedBox();
              return Column(children: [
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.orange, child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Группа'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: g.id, chatName: name, isGroup: true))),
                ),
                const Divider(indent: 72),
              ]);
            }).toList());
          },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final users = snapshot.data!.docs.where((u) => u['uid'] != me.uid).toList();
            return Column(children: users.map((u) {
              final name = u['name'] as String;
              if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery.toLowerCase())) return const SizedBox();
              final chatId = _getChatId(me.uid, u['uid']);
              return Column(children: [
                ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFF075E54), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, chatName: name, isGroup: false))),
                ),
                const Divider(indent: 72),
              ]);
            }).toList());
          },
        ),
      ]),
    );
  }
}

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 80, color: Color(0xFF25D366)),
      SizedBox(height: 16),
      Text('Статусы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Скоро будет добавлено', style: TextStyle(color: Colors.grey)),
    ])));
  }
}

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.call, size: 80, color: Color(0xFF25D366)),
      const SizedBox(height: 16),
      const Text('Звонки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        onPressed: () async {
          final url = Uri.parse('https://meet.jit.si/familychat_general');
          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(Icons.video_call),
        label: const Text('Групповой видеозвонок'),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        onPressed: () async {
          final url = Uri.parse('https://meet.jit.si/familychat_audio');
          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(Icons.call),
        label: const Text('Групповой аудиозвонок'),
      ),
    ])));
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;
  const ChatScreen({super.key, required this.chatId, required this.chatName, required this.isGroup});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgCtrl = TextEditingController();
  final picker = ImagePicker();
  bool sending = false;

  Future<void> sendMessage(String text, {String type = 'text'}) async {
    if (text.trim().isEmpty && type == 'text') return;
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'text': text,
      'type': type,
      'sender': user.uid,
      'senderName': user.displayName ?? user.email!.split('@')[0],
      'senderEmail': user.email,
      'time': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });
    if (type == 'text') msgCtrl.clear();
  }

  Future<void> sendImage({bool fromCamera = false}) async {
    final XFile? image = await picker.pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => sending = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(Uri.parse('https://api.imgbb.com/1/upload?key=$IMGBB_API_KEY'), body: {'image': base64Image});
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await sendMessage(data['data']['url'], type: 'image');
      }
    } catch (e) {
      await sendMessage('📷 Фото', type: 'image');
    }
    setState(() => sending = false);
  }

  Future<void> sendLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      await sendMessage('https://maps.google.com/?q=${pos.latitude},${pos.longitude}', type: 'location');
    } catch (e) {
      await sendMessage('📍 Местоположение недоступно', type: 'location');
    }
  }

  Future<void> sendDocument() async {
    final result = await FilePicker.pickFiles();
    if (result != null) await sendMessage('📄 ${result.files.single.name}', type: 'document');
  }

  void showPollDialog() {
    final q = TextEditingController();
    final o1 = TextEditingController();
    final o2 = TextEditingController();
    final o3 = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Создать опрос'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: q, decoration: const InputDecoration(labelText: 'Вопрос')),
        TextField(controller: o1, decoration: const InputDecoration(labelText: 'Вариант 1')),
        TextField(controller: o2, decoration: const InputDecoration(labelText: 'Вариант 2')),
        TextField(controller: o3, decoration: const InputDecoration(labelText: 'Вариант 3 (необязательно)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          onPressed: () {
            Navigator.pop(context);
            String poll = '📊 *${q.text}*\n1️⃣ ${o1.text}\n2️⃣ ${o2.text}';
            if (o3.text.isNotEmpty) poll += '\n3️⃣ ${o3.text}';
            sendMessage(poll, type: 'poll');
          },
          child: const Text('Создать', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _item(Icons.photo_library, 'Галерея', Colors.purple, () { Navigator.pop(context); sendImage(); }),
            _item(Icons.camera_alt, 'Камера', Colors.red, () { Navigator.pop(context); sendImage(fromCamera: true); }),
            _item(Icons.location_on, 'Геолокация', Colors.green, () { Navigator.pop(context); sendLocation(); }),
            _item(Icons.insert_drive_file, 'Документ', Colors.blue, () { Navigator.pop(context); sendDocument(); }),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _item(Icons.poll, 'Опрос', Colors.orange, () { Navigator.pop(context); showPollDialog(); }),
            _item(Icons.video_call, 'Видеозвонок', Colors.teal, () { Navigator.pop(context); _call(); }),
            _item(Icons.call, 'Аудиозвонок', const Color(0xFF075E54), () { Navigator.pop(context); _call(); }),
            _item(Icons.contact_page, 'Контакт', Colors.indigo, () { Navigator.pop(context); sendMessage('👤 Контакт', type: 'contact'); }),
          ]),
        ]),
      ),
    );
  }

  Widget _item(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [
      CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 26)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]));
  }

  void _call() async {
    final url = Uri.parse('https://meet.jit.si/familychat_${widget.chatId}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _time(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMsg(Map<String, dynamic> data, bool isMe) {
    final type = data['type'] ?? 'text';
    final text = data['text'] ?? '';
    if (type == 'image' && text.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(text, width: 200, height: 200, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Text('📷 Фото')));
    }
    if (type == 'location' && text.startsWith('http')) {
      return GestureDetector(
        onTap: () async { final url = Uri.parse(text); if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); },
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, color: Colors.green, size: 20),
          SizedBox(width: 4),
          Text('Открыть геолокацию', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
        ]),
      );
    }
    return Text(text, style: const TextStyle(fontSize: 15));
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFF25D366), radius: 20, child: Icon(widget.isGroup ? Icons.people : Icons.person, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.chatName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const Text('онлайн', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: _call),
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: _call),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Container(
        color: const Color(0xFFECE5DD),
        child: Column(children: [
          if (sending) const LinearProgressIndicator(color: Color(0xFF25D366)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('time').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
                final msgs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final data = msg.data() as Map<String, dynamic>;
                    final isMe = data['sender'] == me;
                    final name = data.containsKey('senderName') ? data['senderName'] as String : (data['senderEmail'] ?? '') as String;
                    final time = _time(data['time'] as Timestamp?);
                    final readBy = List<String>.from(data['readBy'] ?? []);
                    final isRead = readBy.length > 1;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isMe ? 12 : 0), bottomRight: Radius.circular(isMe ? 0 : 12),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!isMe && widget.isGroup) Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
                          _buildMsg(data, isMe),
                          const SizedBox(height: 2),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (isMe) ...[const SizedBox(width: 4), Icon(Icons.done_all, size: 14, color: isRead ? const Color(0xFF4FC3F7) : Colors.grey)],
                          ]),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFFF0F0F0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.attach_file, color: Color(0xFF075E54)), onPressed: showAttachMenu),
              Expanded(child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                child: TextField(
                  controller: msgCtrl, maxLines: null,
                  decoration: const InputDecoration(hintText: 'Сообщение', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onSubmitted: sendMessage,
                ),
              )),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF25D366), radius: 24,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: () => sendMessage(msgCtrl.text)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
