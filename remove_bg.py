from PIL import Image

def remove_background(input_path, output_path):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    
    datas = img.getdata()
    
    new_data = []
    for item in datas:
        # If the pixel is very dark (background), make it transparent
        # We use a small threshold to catch slightly-off-black pixels
        if item[0] < 15 and item[1] < 15 and item[2] < 15:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

if __name__ == "__main__":
    input_file = r"d:\edu_platform_app_afterGoogle\edu_platform_app\assets\images\logo_icon.png"
    output_file = r"d:\edu_platform_app_afterGoogle\edu_platform_app\assets\images\logo_icon.png"
    remove_background(input_file, output_file)
    print("Background removed successfully from logo_icon.png")
