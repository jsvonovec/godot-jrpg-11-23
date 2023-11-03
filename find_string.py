import os
'''
    For the given path, get the List of all files in the directory tree 
'''
def getListOfFiles(dirName):
    # create a list of file and sub directories 
    # names in the given directory 
    listOfFile = os.listdir(dirName)
    allFiles = list()
    # Iterate over all the entries
    for entry in listOfFile:
        # Create full path
        fullPath = os.path.join(dirName, entry)
        # If entry is a directory then get the list of files in this directory 
        if os.path.isdir(fullPath):
            allFiles = allFiles + getListOfFiles(fullPath)
        else:
            allFiles.append(fullPath)
                
    return allFiles        
def main():

    # filter comments possibly
    filter_comments = str(input("Filter out comments? ")) in "yY"
    

    arg = str(input("Input the phrase to search for: "))
    
    dirName = os.path.dirname(os.path.abspath(__file__))
    
    # Get the list of all files in directory tree at given path
    listOfFiles = list()
    for (dirpath, dirnames, filenames) in os.walk(dirName):
        listOfFiles += [os.path.join(dirpath, file) for file in filenames]
        
        
    # Print the files    
    #for elem in listOfFiles:
        #if ".gd" in elem:
            #print(elem)

    
    
    # Search through them
    found_one = False
    for file in listOfFiles:
        if file.rfind('.') == -1 or file.rsplit('.')[1] not in ".tscn.gd.py.txt":
            continue
        linecount = 0
        with open(file, 'r') as f:
            for line in f.readlines():
                linecount += 1
                if arg in line and (not filter_comments or line.lstrip(' \t')[0] != "#"):
                    if not found_one:
                        print('"%s" is found at the following locations:'
                        % arg)
                        found_one = True
                    print('%s::%s\n\t"%s"'
                          % (os.path.relpath(file, dirName), linecount, line.rstrip('\n').lstrip(' \t')))

    if not found_one:
        print("The argument, %s, is not found anywhere within %s."
              % (arg, dirName))
        
    input("Press ENTER to quit.")
    
        
if __name__ == '__main__':
    main()
