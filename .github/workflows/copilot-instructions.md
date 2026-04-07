# ClassHub - Copilot Instructions

## Project
Flutter mobile app for ISIMM university students. GitHub meets Google Classroom concept .
Students can create public/private repos of course materials and discover other students' work.

## Stack
- Flutter + Dart
- Material Design 3
- Geist font for all text
- file_picker package (temporary, PC only)

## File Structure
lib/
├── main.dart
├── screens/
│   ├── landing_page.dart       ✅ finished
│   ├── folder_selection.dart   🔄 working (PC file picker, temporary)
│   └── main_screen.dart        🔄 working (UI in progress, not fully finished)

## Screens Status
- landing_page.dart → fully finished, custom dark UI
- folder_selection.dart → working but uses PC file picker temporarily.
  Will be replaced when collaborator finishes phone storage permission feature.
- main_screen.dart → working on UI, but not fully finished. Still needs the 3-tab bottom navigation and content for each tab.

## Pending Tasks
- Replace FilePicker.getDirectoryPath() with phone storage picker and permission handling (collaborator's task)
- Build main_screen.dart (3-tab bottom navigation) and content for each tab (my task)

## Design
- Dark blue-black background palette with light blue accents
- 3-tab bottom navigation 
- Material Design 3 components
- Geist font for all text

## Copilot Instruction
After every change we make together, update this file to reflect the new state of the project.
Update screen statuses, pending tasks, and any new decisions made about design or implementation. This will help us keep track of our progress and ensure we're aligned on the next steps for the project .