# Windows installer

The Inno Setup definition is `packaging/windows/AtomBrowser.iss`.
The tested install path is `C:\Program Files\Atom Browser`.
The default profile is `%LOCALAPPDATA%\Atom Browser\User Data`.

The versioned runtime directory `156.0.8078.79` and matching assembly manifest are required. Do not flatten these files into the application root. AppContainer receives read/execute access; do not disable Sandbox.

The alpha installer is unsigned. Before enterprise rollout, implement code signing, update/rollback strategy, uninstall testing and SBOM/dependency review.
