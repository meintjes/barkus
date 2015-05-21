call C:\"Program Files"\dart\dart-sdk\bin\pub.bat global activate rpc
call C:\"Program Files"\dart\dart-sdk\bin\pub.bat run rpc:generate client -i lib/server/draftapi.dart -o lib/client
pause