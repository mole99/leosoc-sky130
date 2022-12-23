# SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import sys
import argparse

def main(binfile, wordsize, output, splits=1):

    print(f'Reading "{binfile}" and writing in {splits} files(s) with wordsize {wordsize}')

    if output == '':
        filename, file_extension = os.path.splitext(binfile)
        output = filename

    with open(binfile, 'rb') as f:
        bindata = f.read()

    print(f'Length of binary: {len(bindata)}')

    if (len(bindata) > 4*wordsize*splits):
        print('Error: Binary too big!')
        sys.exit(-1)
        
    if (len(bindata) % 4 != 0):
        print('Error: Binary not a multiple of 4!')
        sys.exit(-1)

    for i in range(splits):
    
        out_file = f'{output}_{i}.hex'
    
        print(f'Writing to {out_file}...')
    
        with open(out_file, 'w') as f:
    
            for j in range(wordsize):
                word = 0x00000000
                if len(bindata) > 0:
                    word = bindata[0:4]
                    bindata = bindata[4:]
                    word = int.from_bytes(bytes(word), "little")
                
                
                f.write(f'{word:08X}\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('binary')
    parser.add_argument('wordsize', type=int)
    parser.add_argument('--splits', '-s', type=int, default=1)
    parser.add_argument('--output', '-o', type=str, default='')
    args = parser.parse_args()

    main(args.binary, args.wordsize, args.output, args.splits)
