<p align="center">
  <img src="assets/icon/icon.png" width="96" alt="Classhub logo" />
</p>

<h1 align="center">Classhub</h1>

<p align="center">
  <b>Fetch documents from GitHub, Google Drive, and more to your Android device.</b>
</p>

<p align="center">
  <a href="https://classhub.knisium.com">classhub.knisium.com</a>
</p>

<p align="center">
  <a href="https://github.com/titanknis/classhub/releases/latest/download/classhub.apk">
    <img src="https://img.shields.io/badge/Download-latest%20APK-00C853?style=for-the-badge&logo=android" height="40" alt="Download APK" />
  </a>
  <a href="https://github.com/titanknis/classhub">
    <img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" height="40" alt="Get it on Obtainium" />
  </a>
</p>

---

## What is Classhub?

Classhub is a free and open source Android app that fetches files from remote sources like GitHub directly to your device. Point it at a source (GitHub repo, Google Drive folder, or Google Classroom) and it downloads everything to a local folder so you can work offline, open them in any app. Keeps your workflow simple, fast and efficient.

### Features

- **Fetch from GitHub** pull files from any public or private repo (fully supported)
- **Fetch from Google Drive** link a shared Drive folder (planned)
- **Fetch from Google Classroom** auto-fetch coursework (planned)
- **File Explorer** browse, rename, delete, and share fetched files
- **Share to AI chatbots** send documents to Claude, ChatGPT, or any app for summaries and explanations
- **Share any file or folder** zip directories on the fly, share via any app
- **In-app updates** check for new versions and install directly
- **Add from link** share sources via `classhub.knisium.com/add?url=...`
- **Material Design 3** dynamic color theming

## Screenshots

<p align="center">
  <i>Screenshots coming soon.</i>
</p>

## Download

| Method         | Link                                                                                                             |
| -------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Direct APK** | [Download the latest release](https://github.com/titanknis/classhub/releases/latest/download/classhub.apk)       |
| **Obtainium**  | [`obtainium://add/https://github.com/titanknis/classhub`](obtainium://add/https://github.com/titanknis/classhub) |

Obtainium will automatically check for new versions and notify you when an update is available.

## Building from source

Requires [Nix](https://nixos.org/download) with flakes enabled.

```bash
git clone https://github.com/titanknis/classhub.git
cd classhub
nix develop
flutter pub get
flutter build apk --debug
```

## Team

Built by the **Classhub team**, by students for students.

## License

Classhub is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See the [LICENSE](LICENSE) file for details.

## Support

If Classhub helps you stay on top of your coursework, consider [leaving a star](https://github.com/titanknis/classhub) on GitHub, it means a lot.

---

<p align="center">
  <a href="https://classhub.knisium.com">Website</a> •
  <a href="https://github.com/titanknis/classhub/releases">Releases</a> •
  <a href="https://github.com/titanknis/classhub/issues">Issues</a>
</p>
