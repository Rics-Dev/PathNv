import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathnv/data/path.dart';
import 'package:process_run/stdio.dart';
import 'package:yaru/yaru.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:process_run/process_run.dart';

Future<void> main() async {
  await YaruWindowTitleBar.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return YaruTheme(builder: (context, yaru, child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: yaru.theme,
        darkTheme: yaru.darkTheme,
        home: const _Home(),
      );
    });
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  List<Paths> paths = [];
  bool isRefreshing = false;
  bool isSearching = false;

  void runShellCommand() async {
    String shell = Platform.environment['SHELL'] ?? 'sh';
    String command = 'echo \$PATH';

    ProcessResult result = await Process.run(shell, ['-i', '-c', command]);

    String pathResult = result.stdout.trim();

    setState(() {
      paths = pathResult.split(':').map((path) => Paths(path)).toList();
      isRefreshing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    runShellCommand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: YaruWindowTitleBar(
        leading: Center(
          child: YaruOptionButton(
            child: const Icon(LucideIcons.plus),
            onPressed: () {
              print("Pressed");
            },
          ),
        ),
        actions: [
          YaruSearchButton(
            icon: isSearching
                ? const Icon(LucideIcons.x)
                : const Icon(LucideIcons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
              });
            },
          ),
          const SizedBox(width: 8),
          YaruOptionButton(
            child: isRefreshing
                ? const YaruCircularProgressIndicator()
                : const Icon(LucideIcons.refreshCw),
            onPressed: () {
              setState(() {
                isRefreshing = true;
              });
              runShellCommand();
            },
          ),
          const SizedBox(width: 8),
          YaruPopupMenuButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            childPadding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.menu),
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text("Preferences"),
              ),
              const PopupMenuItem(
                child: Text("Keyboard Shortcuts"),
              ),
              PopupMenuItem(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    titlePadding: EdgeInsets.zero,
                    title: YaruDialogTitleBar(
                      isClosable: true,
                    ),
                    content: Text("Heeey"),
                  ),
                ),
                child: const Text("About PathNv"),
              ),
            ],
            child: const Text(""),
          )
        ],
        title: isSearching
            ? const YaruSearchField(
                text: "",
              )
            : const Text("PathNv"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kYaruPagePadding),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.terminal),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    "Paths",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              for (Paths path in paths)
                YaruTile(
                  style: YaruTileStyle.normal,
                  leading: path.isEditing
                      ? YaruIconButton(
                          icon: const Icon(LucideIcons.folder),
                          onPressed: () async {
                            String? selectedDirectory =
                                await FilePicker.platform.getDirectoryPath();
                            print(selectedDirectory);
                          },
                        )
                      : null,
                  trailing: Row(
                    children: [
                      if (path.isEditing) ...[
                        YaruIconButton(
                          icon: const Icon(LucideIcons.check),
                          onPressed: () {
                            setState(() {
                              path.isEditing = !path.isEditing;
                            });
                          },
                        ),
                        YaruIconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              path.isEditing = false;
                            });
                          },
                        ),
                      ] else ...[
                        YaruIconButton(
                          icon: const Icon(LucideIcons.pencil),
                          onPressed: () {
                            setState(() {
                              path.isEditing = !path.isEditing;
                            });
                          },
                        ),
                        YaruIconButton(
                          icon: const Icon(
                            LucideIcons.trash,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            deletePathDialog(context, path);
                          },
                        ),
                      ],
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 26),
                  title: path.isEditing
                      ? YaruSearchField(
                          text: path.path,
                        )
                      : SelectableText(path.path),
                ),
            ],
          )
        ],
      ),
    );
  }

  Future<dynamic> deletePathDialog(BuildContext context, Paths path) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Path"),
          content: const Text("Are you sure you want to delete this path?"),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  paths.remove(path);
                });
                Navigator.pop(context);
              },
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
          ],
        );
      },
    );
  }
}
