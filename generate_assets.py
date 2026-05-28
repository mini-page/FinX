import os
from PIL import Image

def generate_assets():
    source_path = 'assets/icon/brand_logo.png'
    if not os.path.exists(source_path):
        # Fallback to FinX_logo.png if brand_logo.png doesn't exist
        source_path = 'assets/images/FinX_logo.png'
        
    print(f"Using source image: {source_path}")
    source_im = Image.open(source_path)
    
    # 1. Generate xpens_logo.png (1024x1024, transparent bg, logo at 100% or slightly centered)
    # Since brand_logo.png might already be transparent, we can just save it or composite it.
    xpens_logo_path = 'assets/images/xpens_logo.png'
    xpens_logo = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    # Resize source image to 1024x1024 if it's not already
    logo_resized = source_im.resize((1024, 1024), Image.Resampling.LANCZOS)
    xpens_logo.paste(logo_resized, (0, 0), logo_resized if logo_resized.mode == 'RGBA' else None)
    xpens_logo.save(xpens_logo_path, "PNG")
    print(f"Generated {xpens_logo_path}")
    
    # 2. Generate app_icon.png (1024x1024, solid dark navy #0E1626, no alpha)
    # Background color is #0E1626, which is (14, 22, 38) in RGB.
    app_icon_path = 'assets/icon/app_icon.png'
    app_icon = Image.new("RGB", (1024, 1024), (14, 22, 38))
    # Paste logo in the center
    app_icon.paste(logo_resized, (0, 0), logo_resized if logo_resized.mode == 'RGBA' else None)
    app_icon.save(app_icon_path, "PNG")
    print(f"Generated {app_icon_path}")
    
    # 3. Generate app_icon_fg.png (1024x1024, transparent background, logo scaled to ~680x680 centered)
    app_icon_fg_path = 'assets/icon/app_icon_fg.png'
    app_icon_fg = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    fg_size = 680
    fg_resized = source_im.resize((fg_size, fg_size), Image.Resampling.LANCZOS)
    offset = (1024 - fg_size) // 2
    app_icon_fg.paste(fg_resized, (offset, offset), fg_resized if fg_resized.mode == 'RGBA' else None)
    app_icon_fg.save(app_icon_fg_path, "PNG")
    print(f"Generated {app_icon_fg_path}")
    
    # 4. Generate splash_mark.png (512x512, transparent background, logo scaled to ~300x300 centered)
    splash_mark_path = 'assets/icon/splash_mark.png'
    splash_mark = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
    splash_size = 300
    splash_resized = source_im.resize((splash_size, splash_size), Image.Resampling.LANCZOS)
    offset_splash = (512 - splash_size) // 2
    splash_mark.paste(splash_resized, (offset_splash, offset_splash), splash_resized if splash_resized.mode == 'RGBA' else None)
    splash_mark.save(splash_mark_path, "PNG")
    print(f"Generated {splash_mark_path}")
    
    print("All assets successfully generated!")

if __name__ == "__main__":
    generate_assets()
