import os
import sys
import json
import urllib.request
import urllib.parse
import subprocess

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "frontend", "FableApp", "Assets.xcassets")
USER_AGENT = "FableApp/1.0 (academic capstone presentation; contact@fable.app)"

# Map of asset names to Wikimedia Commons filenames or direct image URLs
ASSETS_MAP = {
    # Book covers
    "cover_dracula": "Dracula1st.jpeg",
    "hero_castle": "Bran Castle cloudy.jpg",
    "thumb_sleepy": "MU KPB 019 The Legend of Sleepy Hollow - Illustrated by Arthur Rackham 8.jpg",
    "cover_sleepy_featured": "MU KPB 019 The Legend of Sleepy Hollow - Illustrated by Arthur Rackham 8.jpg",
    "thumb_metamorphosis": "Franz Kafka Die Verwandlung 1916 Orig.-Pappband.jpg",
    "thumb_tell_tale": "Edgar Allan Poe, circa 1849, restored, squared off.jpg",
    "thumb_maria_makiling": "Mount Makiling.jpg",
    "thumb_rip_van_winkle": "Rip Van Winkle-011.jpg",

    # Author portraits
    "author_kuang": "Rf kuang 2023 2.jpg",
    "author_yarros": "NBF2024-rebecca-yarros.jpg",
    "author_klune": "2023 National Book Festival (53123258619) (cropped).jpg",
    "author_moreno": "Silvia Moreno-Garcia.jpg",
    "avatar_roosc": "File:Jose Rizal 1888.jpg",

    # Genre backgrounds
    "genre_folklore": "Ivan Bilibin 182.jpg",
    "genre_mythology": "Jean-Auguste-Dominique Ingres - Jupiter and Thetis - Google Art Project.jpg",
    "genre_gothic": "Caspar David Friedrich - Abtei im Eichwald - Google Art Project.jpg",
    "genre_mystery": "Portrait of Sherlock Holmes by Sidney Paget-Cropped.jpg"
}

def download_wikimedia_file(wiki_filename, target_path):
    # Clean name if it starts with File:
    if wiki_filename.startswith("File:"):
        wiki_filename = wiki_filename[5:]
    
    encoded_name = urllib.parse.quote(wiki_filename.replace(" ", "_"))
    url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{encoded_name}?width=800"
    
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=20) as resp:
        content = resp.read()
        with open(target_path, "wb") as f:
            f.write(content)

def setup_image_set(asset_name, wiki_filename):
    imageset_dir = os.path.join(ASSETS_DIR, f"{asset_name}.imageset")
    os.makedirs(imageset_dir, exist_ok=True)
    
    temp_target = os.path.join(imageset_dir, "raw_download")
    final_filename = f"{asset_name}.jpg"
    final_path = os.path.join(imageset_dir, final_filename)
    
    print(f"[*] Downloading {asset_name} from {wiki_filename}...")
    try:
        download_wikimedia_file(wiki_filename, temp_target)
        
        # Use macOS sips to convert and optimize to max 800px width/height JPEG
        subprocess.run(
            ["/usr/bin/sips", "-s", "format", "jpeg", "-Z", "800", temp_target, "--out", final_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        if os.path.exists(temp_target) and temp_target != final_path:
            os.remove(temp_target)
            
        # Write Contents.json
        contents = {
            "images": [
                {
                    "filename": final_filename,
                    "idiom": "universal",
                    "scale": "1x"
                },
                {
                    "idiom": "universal",
                    "scale": "2x"
                },
                {
                    "idiom": "universal",
                    "scale": "3x"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"[+] Successfully installed {asset_name} ({os.path.getsize(final_path)} bytes)")
        return True
    except Exception as e:
        print(f"[-] Failed to download/install {asset_name}: {e}")
        if os.path.exists(temp_target):
            try:
                os.remove(temp_target)
            except:
                pass
        return False

def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    success_count = 0
    for asset_name, wiki_filename in ASSETS_MAP.items():
        if setup_image_set(asset_name, wiki_filename):
            success_count += 1
            
    print(f"\nCompleted: {success_count}/{len(ASSETS_MAP)} assets installed into {ASSETS_DIR}")

if __name__ == "__main__":
    main()
