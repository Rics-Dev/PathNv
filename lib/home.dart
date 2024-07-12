import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pathnv/model/path.dart';
import 'package:process_run/stdio.dart';
import 'package:yaru/yaru.dart';
import 'package:lucide_icons/lucide_icons.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  List<Paths> paths = [];
  List<Paths> filteredPaths = [];
  bool isRefreshing = false;
  bool isSearching = false;
  String searchQuery = '';
  String shell = Platform.environment['SHELL'] ?? 'sh';
  String? newAddedPath = '';
  TextEditingController pathController = TextEditingController();

  void runShellCommand() async {
    String command = 'echo \$PATH';

    ProcessResult result =
        await Process.run(shell, ['-l', '-i', '-c', command]);

    String pathResult = result.stdout.trim();

    setState(() {
      paths = pathResult.split(':').map((path) => Paths(path)).toList();
      filteredPaths = List.from(paths);
      isRefreshing = false;
    });
  }

  String _getShellConfigFile(String home) {
    final configFiles = {
      'bash': '$home/.bashrc',
      'zsh': '$home/.zshrc',
      'fish': '$home/.config/fish/config.fish',
      'csh': '$home/.cshrc',
      'tcsh': '$home/.cshrc',
      'ksh': '$home/.kshrc',
    };

    return configFiles.entries
        .firstWhere((entry) => shell.contains(entry.key),
            orElse: () => MapEntry('bash', '$home/.bashrc'))
        .value;
  }

  void filterPaths(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredPaths = List.from(paths);
      } else {
        filteredPaths = paths
            .where(
                (path) => path.path.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> addNewPath(String newPath) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final shellConfigFile = _getShellConfigFile(home);

    final file = File(shellConfigFile);
    await file.writeAsString('\nexport PATH="\$PATH:$newPath"\n',
        mode: FileMode.append);

    runShellCommand();
  }

  Future<void> deletePath(String pathToDelete) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final shellConfigFile = _getShellConfigFile(home);

    final file = File(shellConfigFile);
    if (!await file.exists()) {
      if (kDebugMode) {
        print('Config file not found: $shellConfigFile');
      }
      return;
    }

    final lines = await file.readAsLines();

    final updatedLines = lines.where((line) {
      if (line.trim().startsWith('export PATH=')) {
        final paths = line.split(':');
        return !paths.any((path) => path.contains(pathToDelete));
      }
      return true;
    }).toList();

    await file.writeAsString(updatedLines.join('\n'));

    runShellCommand();
  }

  Future<void> editPath(String oldPath, String newPath) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final shellConfigFile = _getShellConfigFile(home);

    final file = File(shellConfigFile);
    if (!await file.exists()) {
      if (kDebugMode) {
        print('Config file not found: $shellConfigFile');
      }
      return;
    }

    final lines = await file.readAsLines();

    final updatedLines = lines.map((line) {
      if (line.trim().startsWith('export PATH=')) {
        return line.replaceAll(oldPath, newPath);
      }
      return line;
    }).toList();

    await file.writeAsString(updatedLines.join('\n'));

    runShellCommand();
  }

  @override
  void initState() {
    super.initState();
    runShellCommand();
  }

  @override
  void dispose() {
    pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: YaruWindowTitleBar(
        leading: Center(
          child: YaruOptionButton(
            child: const Icon(LucideIcons.plus),
            onPressed: () {
              addPathDialog(context);
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
                searchQuery = '';
                filteredPaths = List.from(paths);
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
            ? YaruSearchField(
                text: searchQuery,
                onChanged: filterPaths,
              )
            : const Text("PathNv"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kYaruPagePadding),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.terminal),
                      const SizedBox(width: 8),
                      SelectableText(
                        shell.split('/').last,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text("(${filteredPaths.length})")
                ],
              ),
              for (Paths path in filteredPaths) ...[
                YaruTile(
                  style: YaruTileStyle.normal,
                  leading: path.isEditing
                      ? YaruIconButton(
                          icon: const Icon(LucideIcons.folder),
                          onPressed: () async {
                            String? selectedDirectory =
                                await FilePicker.platform.getDirectoryPath();
                            if (selectedDirectory != null) {
                              setState(() {
                                pathController.text = selectedDirectory;
                              });
                            }
                          },
                        )
                      : null,
                  trailing: Row(
                    children: [
                      if (path.isEditing) ...[
                        YaruIconButton(
                          icon: const Icon(LucideIcons.check),
                          onPressed: () {
                            editPathDialog(context, path, pathController.text);
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
                              path.isEditing = true;
                              pathController.text = path.path;
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
                          controller: pathController,
                          onChanged: (value) {
                            setState(() {
                              // path.newPath = value;
                              pathController.text = value;
                            });
                          },
                        )
                      : SelectableText(path.path),
                ),
                const Divider(),
              ],
            ],
          )
        ],
      ),
    );
  }

  Future<dynamic> addPathDialog(BuildContext context) {
    TextEditingController pathController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        String newPath = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return SimpleDialog(
              contentPadding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 16.0),
              title: const Text("Add Path"),
              children: [
                YaruTile(
                  leading: YaruIconButton(
                    icon: const Icon(LucideIcons.folder),
                    onPressed: () async {
                      String? selectedDirectoryPath =
                          await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectoryPath != null) {
                        setState(() {
                          newPath = selectedDirectoryPath;
                          pathController.text = newPath;
                        });
                      }
                    },
                  ),
                  title: SizedBox(
                    width: 500,
                    child: YaruSearchField(
                      style: YaruSearchFieldStyle.filledOutlined,
                      radius: const Radius.circular(8),
                      hintText: "Enter path",
                      controller: pathController,
                      onChanged: (value) {
                        setState(() {
                          newPath = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        if (newPath.isNotEmpty) {
                          addNewPath(newPath);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      pathController.dispose();
    });
  }

  Future<dynamic> editPathDialog(
      BuildContext context, Paths path, String newPath) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Path"),
          content: Text(
              "Are you sure you want to change the path from:\n\n${path.path}\n\nto:\n\n$newPath"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  path.isEditing = false;
                });
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (newPath.isNotEmpty && newPath != path.path) {
                  editPath(path.path, newPath);
                  setState(() {
                    path.isEditing = false;
                    path.path = newPath;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> deletePathDialog(BuildContext context, Paths path) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Path"),
          content: Text(
              "Are you sure you want to delete this path?\n\n${path.path} "),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                if (path.path.isNotEmpty) {
                  deletePath(path.path);
                  Navigator.pop(context);
                }
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }
}
