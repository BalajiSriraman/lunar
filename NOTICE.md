# Third-party source

Lunar includes a modified copy of [Moonlight Qt v6.2.0](https://github.com/moonlight-stream/moonlight-qt/tree/v6.2.0), under GNU GPL v3. Copyright notices and license files are retained in `vendor/moonlight-qt-6.2.0`.

The local changes provide a native frontend, a separate settings domain, and native application commands. The engine patch is in `patches/native-ui.patch`, with its added source files beside it.

The following upstream source dependencies are included at the revisions used by Moonlight v6.2.0:

| Component | Revision |
| --- | --- |
| moonlight-common-c | `f900dd4767759c7b9d0e93bcea666b55c69ea62f` |
| ENet | `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1` |
| nanors | `b1e3c22ca0cdc0bb83e3cd6ed1a2fc77869ed99a` |
| qmdnsengine | `920c097ffa742e2968290f15d4dde6693aec02e5` |
| SDL GameControllerDB | `8d9fefd7b810f2541f78cc7a8ccbd185bc84c7a5` |

Each component retains its own copyright and license terms in its source directory. The upstream engine also includes h264bitstream and its license files.

The build downloads the official Moonlight Qt dependency package through upstream `setup-deps.py`. These libraries and the Homebrew Qt libraries are not committed to this repository.
