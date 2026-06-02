# Run Lumio — `flutter run` with ads (একবার সেটআপ)

## একবার করুন (টার্মিনাল)

`~/.bashrc`-এর শেষে যোগ করুন:

```bash
source ~/Downloads/FlutterProject/lumio/scripts/flutter_env.sh
```

তারপর:

```bash
source ~/.bashrc
cd ~/Downloads/FlutterProject/lumio
flutter run
```

এখন **সাধারণ `flutter run`**-ই `secrets.json` (ads, LevelPlay, Toffee, …) লোড করবে — `./scripts/flutter_run_with_ads.sh` বা `./run` আর বাধ্য নয়।

## Cursor / VS Code

`.vscode/settings.json` ইতিমধ্যে সেট — **Run → Lumio (debug + ads)** বা টার্মিনালে `flutter run` (উপরের bashrc সোর্স থাকলে)।

## `secrets.json` নেই?

```bash
cp secrets.json.template secrets.json
# keys ভরুন (কমিট করবেন না)
```

## যাচাই

লগে:

```text
[AdConfig] … ADS_ENABLED=<set> … hasMonetizationConfig=<set>
```

লাল **ADS DISABLED** ব্যানার থাকলে `secrets.json` নেই বা bashrc সোর্স হয়নি।

## Ads ছাড়া UI

```bash
flutter run --dart-define=ALLOW_SILENT_DEBUG_ADS=true
```

## Hot reload

`secrets.json` বদলালে **full restart** (R) — hot reload যথেষ্ট নয়।
