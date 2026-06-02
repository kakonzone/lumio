#!/usr/bin/env python3
"""
Font Subsetting Script
Reduces font file size by including only used characters.
Requires: pyftsubset (from fonttools package)
Install: pip install fonttools brotli
"""

import subprocess
import sys
from pathlib import Path

# Characters used in the app (Bengali + English + Numbers + Symbols)
UNICODE_RANGES = [
    # Bengali (U+0980 to U+09FF)
    "U+0980-U+09FF",
    # Basic Latin (U+0020 to U+007F)
    "U+0020-U+007F",
    # Latin-1 Supplement (U+0080 to U+00FF)
    "U+0080-U+00FF",
    # Numbers and common symbols
    "U+0030-U+0039",  # 0-9
    "U+0021-U+002F",  # ! " # $ % & ' ( ) * + , - . /
    "U+003A-U+0040",  # : ; < = > ? @
]

def subset_font(input_path: Path, output_path: Path):
    """Subset a font file to include only needed characters."""
    unicode_ranges = ",".join(UNICODE_RANGES)
    
    cmd = [
        "pyftsubset",
        str(input_path),
        "--output-file=" + str(output_path),
        "--unicodes=" + unicode_ranges,
        "--flavor=woff2",
        "--layout-features-=*",
        "--glyph-names",
        "--symbol-cmap",
        "--recalc-bounds",
        "--prune-codepages",
    ]
    
    print(f"Subsetting {input_path.name}...")
    try:
        subprocess.run(cmd, check=True)
        print(f"✓ Created {output_path.name}")
        
        # Show size reduction
        original_size = input_path.stat().st_size
        new_size = output_path.stat().st_size
        reduction = (1 - new_size / original_size) * 100
        print(f"  Size: {original_size // 1024}KB → {new_size // 1024}KB ({reduction:.1f}% reduction)")
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed to subset {input_path.name}: {e}")
        return False
    return True

def main():
    assets_dir = Path(__file__).parent.parent / "assets" / "fonts"
    
    if not assets_dir.exists():
        print(f"Font directory not found: {assets_dir}")
        sys.exit(1)
    
    # Check if pyftsubset is available
    try:
        subprocess.run(["pyftsubset", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: pyftsubset not found.")
        print("Install with: pip install fonttools brotli")
        sys.exit(1)
    
    print("🔤 Font Subsetting Started")
    print("=" * 50)
    
    fonts = [
        "Barlow-Regular.ttf",
        "Barlow-Bold.ttf",
        "BarlowCondensed-Bold.ttf",
    ]
    
    success_count = 0
    for font_name in fonts:
        input_path = assets_dir / font_name
        output_path = assets_dir / f"{font_name}.woff2"
        
        if input_path.exists():
            if subset_font(input_path, output_path):
                success_count += 1
        else:
            print(f"✗ Font not found: {font_name}")
    
    print("=" * 50)
    print(f"✓ Completed: {success_count}/{len(fonts)} fonts subsetted")
    
    if success_count > 0:
        print("\n📝 Next steps:")
        print("1. Update pubspec.yaml to use .woff2 files instead of .ttf")
        print("2. Run: flutter clean && flutter pub get")
        print("3. Build: flutter build apk --release --split-per-abi")

if __name__ == "__main__":
    main()
