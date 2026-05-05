import sys
import itertools

if len(sys.argv) < 3:
    print("Split object files at first difference")
    print("Useage: split_diff obj-file obj-file [output-file]")
    quit()


# Using readlines()
filename1 = sys.argv[1]
if filename1.find(".") < 0:
    filename1 += ".obj"

filename2 = sys.argv[2]
if filename2.find(".") < 0:
    filename2 += ".obj"

name = filename2.split(".")[0]
outfile = name+".diff"

if len(sys.argv) > 3:
    outfile = sys.argv[3]

if outfile.find(".") < 0:
    outfile += ".diff"

print("Parsing {} diff {} -> {}".format(filename1, filename2,outfile))

file1 = open(filename1, 'r')
lines1 = file1.readlines()

file2 = open(filename2, 'r')
lines2 = file2.readlines()

matches = True
output = []

for l1, l2 in itertools.zip_longest(lines1, lines2):
    if l1 != l2:
        matches = False

    if not matches and l2 is not None:
        output.append(l2) 


file1 = open(outfile, 'w')
file1.writelines(output)
file1.close()
