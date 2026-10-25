' WebSlideSwitch バックグラウンド起動スクリプト
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)

' start.batを非表示（0: 画面非表示）で実行
WshShell.Run "cmd /c """ & currentDir & "\start.bat""", 0, False
