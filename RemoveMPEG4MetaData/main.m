//
//  main.m
//  RemoveMPEG4MetaData
//
//  Copyright (c) 2012 Mike McQuaid. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPEG4File.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        NSProcessInfo *processInfo = NSProcessInfo.processInfo;

        if(processInfo.arguments.count != 3) {
            fprintf(stderr, "usage: %s [input] [output]\n",
                    processInfo.processName.UTF8String);
            return 1;
        }

        NSString *inFileName = [processInfo.arguments objectAtIndex:1];
        MPEG4File *inFile = [MPEG4File.alloc initWithPath:inFileName];
        if(!inFile)
            return 1;
        //[inFile printAtomNames];

        NSString *outFileName = [processInfo.arguments objectAtIndex:2];
        [inFile removeMetaDataAndWriteToFileName:outFileName];
        //[[MPEG4File.alloc initWithPath:outFileName] printAtomNames];

        return 0;
    }
}
