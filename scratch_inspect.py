from PIL import Image
import os

print("--- Image Inspection ---")
for path in ['assets/icon/brand_logo.png', 'assets/images/FinX_logo.png']:
    abs_path = os.path.abspath(path)
    if os.path.exists(abs_path):
        im = Image.open(abs_path)
        print(f'{path}: format={im.format}, size={im.size}, mode={im.mode}')
    else:
        print(f'{path} does not exist at {abs_path}')
