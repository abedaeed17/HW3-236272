import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text(snapshot.error.toString(), textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (BuildContext context) => UserStatusNotifier(),
      child: Consumer<UserStatusNotifier>(
        builder: (context, appUser, _) => MaterialApp(
          title: 'Startup Name Generator',
          initialRoute: '/',
          routes: {
            '/': (context) => const RandomWords(),
            '/login': (context) => const Login(),
          },
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            primaryColor: Colors.deepPurple,
          ),
        ),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _saved = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;
  var canDrag = true;
  SnappingSheetController sheetController = SnappingSheetController();

  @override
  Widget build(BuildContext context) {
    user = Provider.of<UserStatusNotifier>(context);
    var authIcon =
        user.status == Status.authenticated ? const Icon(Icons.exit_to_app) : const Icon(Icons.login);
    var authIconFunction = user.status == Status.authenticated
        ? (() async {
            sheetController.snapToPosition(const SnappingPosition.factor(positionFactor: 0.083));
            canDrag = false;
            await user.signOut();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Successfully logged out')));
          })
        : (() => Navigator.pushNamed(context, '/login'));
    var authToolTip = user.status == Status.authenticated ? 'Logout' : 'Login';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon: authIcon,
            onPressed: authIconFunction,
            tooltip: authToolTip,
          )
        ],
      ),
      body: GestureDetector(
          child: SnappingSheet(
            controller: sheetController,
            snappingPositions: const [
              SnappingPosition.pixels(
                  positionPixels: 190,
                  snappingCurve: Curves.bounceOut,
                  snappingDuration: Duration(milliseconds: 350)),
              SnappingPosition.factor(
                  positionFactor: 1.0,
                  snappingCurve: Curves.easeInBack,
                  snappingDuration: Duration(milliseconds: 1)),
            ],
            lockOverflowDrag: true,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildSuggestions(),
                BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 5,
                    sigmaY: 5,
                  ),
                  child: canDrag && user.status == Status.authenticated
                      ? Container(
                          color: Colors.transparent,
                        )
                      : null,
                )
              ],
            ),
            sheetBelow: user.status == Status.authenticated
                ? SnappingSheetContent(
                    draggable: canDrag,
                    child: Container(
                      color: Colors.white,
                      child: ListView(physics: const NeverScrollableScrollPhysics(), children: [
                        Column(children: [
                          Row(children: <Widget>[
                            Expanded(
                              child: Container(
                                color: Colors.black12,
                                height: 60,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Flexible(
                                        flex: 3,
                                        child: Center(
                                          child: Text("Welcome back, " + user.getUserEmail(),
                                              style: const TextStyle(fontSize: 16.0)),
                                        )),
                                    const IconButton(
                                      icon: Icon(Icons.keyboard_arrow_up),
                                      onPressed: null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                          const Padding(padding: EdgeInsets.all(8)),
                          Row(children: <Widget>[
                            const Padding(padding: EdgeInsets.all(8)),
                            FutureBuilder(
                              future: user.getImageUrl(),
                              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                return CircleAvatar(
                                  radius: 50.0,
                                  backgroundImage: snapshot.data != null
                                      ? NetworkImage(snapshot.data ?? "") //muask might be null
                                      : null,
                                );
                              },
                            ),
                            const Padding(padding: EdgeInsets.all(10)),
                            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(user.getUserEmail(),
                                  style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 20)),
                              const Padding(padding: EdgeInsets.all(3)),
                              MaterialButton(
                                //Change avatar button
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['png', 'jpg', 'gif', 'bmp', 'jpeg', 'webp'],
                                  );
                                  File file;
                                  if (result != null) {
                                    file = File(result.files.single.path ?? "");
                                    user.uploadNewImage(file);
                                  } else {
                                    // User canceled the picker
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content:
                                        Text('No image selected')));
                                  }
                                },
                                textColor: Colors.white,
                                padding: const EdgeInsets.only(left: 5.0, top: 3.0, bottom: 5.0, right: 8.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        Colors.deepPurple,
                                        Colors.blueAccent,
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(15, 7, 15, 7),
                                  child: const Text('Change Avatar', style: TextStyle(fontSize: 15)),
                                ),
                              ),
                            ])
                          ]),
                        ]),
                      ]),
                    ),
                    //heightBehavior: SnappingSheetHeight.fit(),
                  )
                : null,
          ),
          onTap: () => {
                setState(() {
                  if (canDrag == false) {
                    canDrag = true;
                    sheetController.snapToPosition(const SnappingPosition.factor(
                      positionFactor: 0.265,
                    ));
                  } else {
                    canDrag = false;
                    sheetController.snapToPosition(const SnappingPosition.factor(
                        positionFactor: 0.083,
                        snappingCurve: Curves.easeInBack,
                        snappingDuration: Duration(milliseconds: 1)));
                  }
                })
              }),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, i) {
        if (i.isOdd) return const Divider();

        final index = i ~/ 2;
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10));
        }
        final alreadySaved = user.saved.contains(_suggestions[index]);
        return ListTile(
          title: Text(
            _suggestions[index].asPascalCase,
            style: _biggerFont,
          ),
          trailing: Icon(
            alreadySaved ? Icons.favorite : Icons.favorite_border,
            color: alreadySaved ? Colors.red : null,
            semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
          ),
          onTap: () async {
            var pair = _suggestions[index];
            if (alreadySaved) {
              await user.removePair(pair.first, pair.second);
            } else {
              await user.addPair(pair.first, pair.second);
            }
          },
        );
      },
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          var favorites = _saved; //idk
          favorites = user.saved;
          final tiles = favorites.map(
            (pair) {
              return ListTile(
                title: Text(
                  pair.asPascalCase,
                  style: _biggerFont,
                ),
              );
            },
          );

          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView.builder(
              itemCount: divided.length,
              itemBuilder: (context, index) {
                var pair = user.saved.toList()[index];
                return Dismissible(
                  background: Container(
                    color: Colors.deepPurple,
                    child: Row(
                      children: const [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                        Text(
                          'Delete Suggestion',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        )
                      ],
                    ),
                  ),
                  key: UniqueKey(),
                  onDismissed: (dir) async {
                    await user.removePair(pair.first, pair.second);
                  },
                  confirmDismiss: (dir) async {
                    return await getDecision(pair);
                  },
                  child: divided[index],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<bool> getDecision(WordPair name) async {
    bool decision = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Suggestion"),
          content: Text("Are you sure you want to delete ${name.asPascalCase} from your saved suggestions?"),
          actions: [
            TextButton(
              onPressed: () {
                decision = true;
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.deepPurple),
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                decision = false;
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.deepPurple),
              child: const Text("No"),
            )
          ],
        );
      },
    );
    return decision;
  }
}

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserStatusNotifier>(context);
    TextEditingController email = TextEditingController(text: "");
    TextEditingController password = TextEditingController(text: "");
    var validate = true;
    TextEditingController confirm = TextEditingController(text: "");

    var logInButton = user.status == Status.authenticating
        ? const Center(child: CircularProgressIndicator())
        : MaterialButton(
            onPressed: () async {
              if (!await user.signIn(email.text, password.text)) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('There was an error logging into the app')));
              } else {
                Navigator.pop(context);
              }
            },
            minWidth: 350,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
            color: Colors.deepPurple,
            child: const Text('Log in', style: TextStyle(fontSize: 20, color: Colors.white)),
          );

    var signUpButton = user.status == Status.authenticating
        ? const Center(child: CircularProgressIndicator())
        : MaterialButton(
            onPressed: () async {
              //
              // contexts = context;
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return AnimatedPadding(
                    padding: MediaQuery.of(context).viewInsets,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.decelerate,
                    child: Container(
                      height: 200,
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('Please confirm your password below:'),
                            const SizedBox(height: 20),
                            Container(
                              width: 350,
                              child: TextField(
                                controller: confirm,
                                obscureText: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Password',
                                  errorText: validate ? null : 'Passwords must match',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ButtonTheme(
                              minWidth: 350.0,
                              height: 50,
                              child: MaterialButton(
                                  color: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18.0),
                                      side: BorderSide(color: Colors.blue)),
                                  child: Text(
                                    'Confirm',
                                    style: TextStyle(fontSize: 17, color: Colors.white),
                                  ),
                                  onPressed: () async {
                                    if (confirm.text == password.text) {
                                      //do that
                                      // await user.signOut();
                                      user.signUp(email.text, password.text);
                                      //await user.signIn(_email.text, _password.text);
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                    } else {
                                      setState(() {
                                        validate = false;
                                        FocusScope.of(context).requestFocus(FocusNode());
                                      });
                                    }
                                  }),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            minWidth: 350,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
            color: Colors.blue,
            child:
                const Text('New user? Click to sign up', style: TextStyle(fontSize: 20, color: Colors.white)),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Column(children: <Widget>[
        const Padding(
            padding: EdgeInsets.all(25.0),
            child: (Text(
              'Welcome to Startup Names Generator, please log in!',
              style: TextStyle(
                fontSize: 14,
              ),
            ))),
        const SizedBox(height: 40),
        TextField(
          controller: email,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Password',
          ),
        ),
        const SizedBox(height: 40),
        logInButton,
        signUpButton,
      ]),
    );
  }
}

enum Status { authenticated, authenticating, unauthenticated }

class UserStatusNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Status status = Status.unauthenticated;
  List<WordPair> saved = [];

  UserStatusNotifier();

  Future<bool> signUp(String email, String password) async {
    try {
      status = Status.authenticating;
      notifyListeners();
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await uploadLocallySavedWords();
      var defaultProfilePicture =
          "https://firebasestorage.googleapis.com/v0/b/hellome-37eb1.appspot.com/o/blank-profile-picture-973460_1280.webp?alt=media&token=4aa3c403-5bfc-49f3-8a44-18e389015dba";
      await _auth.currentUser?.updatePhotoURL(defaultProfilePicture);
      status = Status.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      status = Status.authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await uploadLocallySavedWords();
      saved = await getSavedWordsFromCloud();
      status = Status.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    status = Status.unauthenticated;
    saved = [];
    notifyListeners();
  }

  Future<void> uploadLocallySavedWords() async {
    if (status == Status.authenticated || status == Status.authenticating) {
      var mappedList = saved.map((e) => {"first": e.first, "second": e.second}).toList();
      await _db
          .collection("Users")
          .doc("SavedWords")
          .update({(_auth.currentUser?.uid ?? ""): FieldValue.arrayUnion(mappedList)});
    }
  }

  Future<List<WordPair>> getSavedWordsFromCloud() async {
    final res = <WordPair>[];
    try {
      var savedWords = await _db.collection("Users").doc("SavedWords").get();
      savedWords[_auth.currentUser?.uid ?? ""].forEach((element) {
        String firstWord = element["first"];
        String secondWord = element["second"];
        res.add(WordPair(firstWord, secondWord));
      });
      return res;
    } catch (e) {
      //In case this user does not have any starred words in the cloud.
      //or if the user didn't sign-in.
      return Future<List<WordPair>>.value([]);
    }
  }

  Future<void> addPair(String first, String second) async {
    saved.add(WordPair(first, second));
    notifyListeners();
    if (status == Status.authenticated) {
      await _db.collection("Users").doc("SavedWords").update({
        (_auth.currentUser?.uid ?? ""): FieldValue.arrayUnion([
          {"first": first, "second": second}
        ])
      });
    }
  }

  Future<void> removePair(String first, String second) async {
    saved.remove(WordPair(first, second));
    notifyListeners();
    if (status == Status.authenticated) {
      await _db.collection("Users").doc("SavedWords").update({
        (_auth.currentUser?.uid ?? ""): FieldValue.arrayRemove([
          {"first": first, "second": second}
        ])
      });
    }
  }

  String getUserEmail() {
    return _auth.currentUser?.email ?? "unknown@unknowndomain.com";
  }

  Future<void> uploadNewImage(File file) async {
    await _storage.ref('images').child(_auth.currentUser?.uid ?? "").putFile(file);
    var newPhotoURL = await _storage.ref('images').child(_auth.currentUser?.uid ?? "").getDownloadURL();
    await _auth.currentUser?.updatePhotoURL(newPhotoURL);
    notifyListeners();
  }

  Future<String> getImageUrl() async {
    var defaultProfilePicture = "https://firebasestorage.googleapis.com/v0/b/hellome-37eb1.appspot.com/o/blank-profile-picture-973460_1280.webp?alt=media&token=4aa3c403-5bfc-49f3-8a44-18e389015dba";
    return _auth.currentUser?.photoURL ?? defaultProfilePicture;
  }
}
