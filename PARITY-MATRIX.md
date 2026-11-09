# UMLExpress — матрица паритета с JetUML 3.10 (M10)

Сверка выполнена по §7 плана (`PLAN-swift-macos.md`) и `docs/user-guide.md` JetUML.
Легенда: ✅ реализовано и покрыто тестами · ⚠️ частично / сознательное отклонение ·
⬜ не реализовано (вне объёма или отложено, причина указана).

## Типы диаграмм

| Внешнее имя (в файле) | Расширение | Диаграмма |
|---|---|---|
| `ClassDiagram` | `.class` | классы, интерфейсы, пакеты, заметки |
| `SequenceDiagram` | `.sequence` | объекты с линиями жизни, вызовы, возвраты |
| `StateDiagram` | `.state` | состояния, начальное/конечное, переходы |
| `ObjectDiagram` | `.object` | объекты, поля, ссылки, коллаборации |
| `UseCaseDiagram` | `.usecase` | акторы, прецеденты, ассоциации/зависимости/обобщения |

Файлы пишутся как `<имя>.<расширение>.jet` (совместимо с JetUML), UTI —
`com.umlexpress.app.diagram`, расширение `jet`.

## Функции

| Функция | Источник в JetUML | Статус | Где в UMLExpress | Проверка |
|---|---|---|---|---|
| 5 типов диаграмм: создание | `DiagramType`, `Prototypes` | ✅ | `DiagramKind.prototypes`, палитра инструментов, `WelcomeWindow` | `AcceptanceTests.testFullCycleForEveryDiagramType` |
| 5 типов: редактирование, удаление | `DiagramBuilder` + 4 подкласса | ✅ | `DiagramBuilder` / 4 билдера | `OperationsTests`, `OtherBuildersTests`, `SequenceBuilderTests` |
| 5 типов: рендеринг | `rendering/*` | ✅ | `AbstractDiagramRenderer` + 5 рендереров диаграмм | `ClassDiagramRendererTests`, `OtherDiagramTypesTests`, `SequenceDiagramTests` |
| Автоматическая маршрутизация рёбер | `ClassDiagramRenderer` (1342 стр.) | ✅ | `ClassDiagramLayouter` | `ClassDiagramLayouterTests` (6 сценариев, эталонные пути) |
| Семантическая валидация с уведомлениями | `diagram/validator/*` | ✅ | 5 валидаторов, 17 constraints, `NSAlert` | `ClassDiagramValidatorTests`, `OtherValidatorsTests`, `SequenceValidatorTests`, `testInvalidOperationsAreRejectedAndReported` |
| Открытие/сохранение `.jet` (schema 3.0) | `persistence/*` | ✅ | `UMLPersistence` | `DiagramCodingTests` (7 файлов из `testdata/`) |
| Валидация при загрузке (3 категории ошибок) | `PersistenceService.read` | ✅ | `DiagramCoding.validate` | `DiagramCodingValidationTests` |
| Undo/redo, dirty-флаг | `DiagramOperationProcessor` | ✅ | то же | `OperationsTests` |
| Duplicate diagram | `Diagram.duplicate` + меню | ✅ | `DiagramDocument.duplicateDocument`, File ▸ Duplicate (⌘D) | `testCopyPasteAndDuplicate` |
| Выделение: клик, ⌘-переключение, лассо | `DiagramCanvas` | ✅ (⌘ вместо Ctrl) | `DiagramCanvasController` | `DiagramCanvasControllerTests` |
| Перетаскивание, выравнивание по сетке | `MoveTracker`, `alignMoveToGrid` | ✅ | то же | `testDragMovesSelectionAndSnapsToGrid` |
| Создание рёбер перетаскиванием, авто-`PointNode` | `createAddEdgeOperation` | ✅ | `DiagramBuilder` | `testNoteEdgeCreatesPointNode`, sequence-тесты |
| Property sheet с автогенерацией полей | `PropertySheet` | ✅ | `PropertySheetModel` + `PropertySheetWindow` | `PropertySheetModelTests` |
| Экспорт SVG | `SvgRenderingContext` | ✅ | `SVGRenderingContext` | `SVGRenderingContextTests` |
| Экспорт PNG/JPEG/TIFF | `createImage` | ✅ | `DiagramExporter` | `testExportsToFiles` |
| Экспорт PDF | — (нет в JetUML) | ✅ бонус | `DiagramExporter.pdf` | `testPDFExport` |
| Copy to Clipboard как изображение | `Clipboard` | ✅ | `ClipboardImage` (TIFF+PNG на `NSPasteboard`) | `testClipboardImageCopy` |
| Тёмная тема | `ColorScheme`, View ▸ Dark Mode | ✅ | `ColorScheme` + меню | `ColorSchemeTests` |
| Сетка на холсте | `DiagramCanvas` grid | ✅ | `DiagramCanvasView.draw` рисует сетку `ColorScheme.grid` | `testCanvasPaintsGridAndDiagram` |
| Настройка шрифта | `FontDialog` | ✅ (через системную панель) | View ▸ Font… → `NSFontPanel` | — (UI-путь) |
| Welcome-страница | `WelcomeTab` | ✅ (отдельное окно) | `WelcomeWindowController` (5 типов + recent) | — (UI-путь) |
| Recent files | `RecentFilesQueue` | ✅ | `RecentFilesQueue` + «Open Recent» | `testRecentFilesQueue`, `testRecentFilesMenuDelegatePopulatesMenu` |
| Нативные табы окон | — (JetUML: табы внутри окна) | ✅ | `NSWindow.tabbingMode` | `testWindowUsesNativeTabs` |
| Тултипы инструментов | `Prototypes.tooltip` | ⚠️ | `Prototypes.tooltip` + `NSButton.toolTip`; verbose-вариант показывает ключи ресурсов | `PrototypesTests` |
| Система подсказок (tips) | `gui/tips/*` (891 стр.) | ⬜ | — | вне объёма итерации: контент подсказок — отдельный корпус текста |
| Локализация | `JetUML.properties` | ⬜ | все строки английские; `PropertyName.visible` возвращает внешнее имя | вне объёма |
| Печать | — (нет в JetUML) | ⬜ | PDF есть, диалога печати нет | — |
| Файлы старше schema 3.0 (XML) | мигратор снят в JetUML 3.6 | ⬜ | сознательно не поддерживается, как и в оригинале | — |
| CSS-тема | `DarkMode.css` | n/a | заменена системными цветами (`NSAppearance`) | — |

## Известные отклонения

1. **⌘ вместо Ctrl** для добавления к выделению — конвенция macOS.
2. **Каждое окно = одна диаграмма**, нативные оконные табы вместо внутренних (решение D2).
3. **Метрики текста CoreText ≠ JavaFX** ⇒ размеры узлов могут отличаться на единицы пикселей; побайтовое сравнение SVG с JetUML невозможно, сравнивается структура (см. `Tests/UMLRenderingTests/RealFileRenderingTests.swift`).
4. **Иконки**: иконки инструментов рисуются рендерерами (`createIcon`, как в оригинале) в `CGImage`, иконки действий взяты из `JetUML/icons/16x16`. Отклонения от оригинала ради читаемости: иконка рисуется с образца элемента (класс с секциями, заметка с текстом, пакет с именем), а не с пустого прототипа; текст мельче 5 pt заменяется приглушённой полоской; содержимое центрируется по обеим осям (в JetUML иконки прижаты к левому верхнему углу); наконечники рёбер уменьшены до 0.55 (иначе ромб агрегации занимает пол-иконки); буква-тег зависимости use case нарисована внутри иконки, а не под ней; толщина обводки не масштабируется; фон прозрачный (в оригинале прозрачный тоже). Кнопка выделения — символ `cursorarrow`.
5. **Property-значения хранятся как `Any`** (как `Object` в Java), а enum-свойства — внешними строками; варианты выпадающих списков заданы таблицей.

## Ручные проверки (не автоматизируются в этой среде)

| Проверка | Почему вручную | Как выполнить |
|---|---|---|
| Взаимодействие мышью на реальном дисплее | нужен window server | `open build/UMLExpress.app`, пройти Quick Tour из `docs/user-guide.md` |
| Сверка SVG с JetUML бок о бок | нужен запуск Java-версии | открыть один `.jet` в обеих версиях, сравнить экспорт |
| Подпись Developer ID + нотаризация | нет сертификата | `codesign --sign "Developer ID Application: …"`, `xcrun notarytool submit` |
| Создание DMG | `hdiutil` запрещён в песочнице агента | `Scripts/build-app.sh` из обычного терминала |
| Работа «Открыть с помощью» | нужен LaunchServices | дважды щёлкнуть `.jet`-файл в Finder |
