from PIL import Image
import argparse

HEIGHT = 75
WIDTH = 100

def main(filename):

    im = Image.open(filename)
    print(f'Loading {filename}')
    print(f'Original size: {im.size}')

    im = im.resize((WIDTH, HEIGHT))
    pix = im.load()
    print(f'New size: {im.size}')


    def convertColor(color):
        
        r = int(color[0]/255*7)
        g = int(color[1]/255*7)
        b = int(color[2]/255*3)
        
        return ((b&3) << 6) | ((g&7) << 3) | r&7

    content = ""

    for y in range(HEIGHT):
        for x in range(WIDTH//4):
            byte0 = convertColor(pix[x*4+0, y])
            byte1 = convertColor(pix[x*4+1, y])
            byte2 = convertColor(pix[x*4+2, y])
            byte3 = convertColor(pix[x*4+3, y])
            content += '{0:08X}\n'.format(byte3<<24|byte2<<16|byte1<<8|byte0)

    index = filename.rfind(".")
    filename = filename[:index] + ".hex"

    print(f'Saving {filename}')
    f = open(filename, "w")
    f.write(content)
    f.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('filename')
    args = parser.parse_args()
    
    main(args.filename)
