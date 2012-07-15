//
//  MPEG4File.m
//  RemoveMPEG4MetaData
//
//  Copyright (c) 2012 Mike McQuaid. All rights reserved.
//

#import "MPEG4File.h"
#import "MPEG4Atom.h"

@implementation MPEG4File
@synthesize fileName = _fileName;
@synthesize data = _data;
@synthesize topLevelAtoms = _topLevelAtoms;

- (id)initWithPath:(NSString*)path {
    self = super.init;
    if(!self)
        return nil;

    _fileName = path;

    NSError *dataError = nil;
    _data = [NSData dataWithContentsOfFile: path
                                   options: NSDataReadingMappedIfSafe
                                     error: &dataError];
    if(!self.data) {
        fprintf(stderr, "%s: error reading file: %s: %s\n",
                NSProcessInfo.processInfo.processName.UTF8String,
                path.UTF8String, dataError.localizedFailureReason.UTF8String);
        return nil;
    }

    // The atoms are effectively arranged in a linked list so
    // we can iterate through the file to find them all.
    NSMutableArray *topLevelAtoms = NSMutableArray.array;
    MPEG4Atom *atom = [MPEG4Atom.alloc initWithData:self.data
                                          andOffset:0];
    while(atom) {
        [topLevelAtoms addObject:atom];
        atom = [atom nextSiblingAtomFromData:self.data];
    }
    _topLevelAtoms = topLevelAtoms;

    return self;
}

- (NSArray*)atomsWithName:(NSString*)name {
    NSMutableArray *foundAtoms = NSMutableArray.array;
    for(MPEG4Atom *atom in self.allAtoms)
        if([atom.name isEqualToString:name])
            [foundAtoms addObject:atom];
    return foundAtoms;
}

- (void)removeMetaDataAndWriteToFileName:(NSString*)path {
    // This assumes there is at most one meta and one mdat atom.
    NSArray *metaAtoms = [self atomsWithName:@"meta"];
    MPEG4Atom *metaAtom = nil;
    if(metaAtoms.count)
        metaAtom = [metaAtoms objectAtIndex:0];
    else {
        fprintf(stdout, "%s: MPEG4 file %s does not contain meta atom; ignoring.\n",
                NSProcessInfo.processInfo.processName.UTF8String, self.fileName.UTF8String);
        return;
    }

    NSArray *mdatAtoms = [self atomsWithName:@"mdat"];
    MPEG4Atom *mdatAtom = nil;
    if (mdatAtoms.count)
        mdatAtom = [mdatAtoms objectAtIndex:0];
    NSArray *allAtoms = self.allAtoms;
    // If the meta atom is before the mdat atom we need to
    // recalculate the offsets in the stco atom.
    bool metaBeforeMdat = [allAtoms indexOfObject:metaAtom] < [allAtoms indexOfObject:mdatAtom];

    NSUInteger metaLength = 0;
    for(MPEG4Atom *atom in allAtoms) {
        if([atom.name isEqualToString:@"meta"]) {
            // We're removing the meta atom so store the length
            // but zero the actual atom.
            metaLength = atom.length;
            atom.length = 0;

            MPEG4Atom *childAtom = atom;
            MPEG4Atom *parentAtom = atom.parentAtom;

            while (parentAtom) {
                NSUInteger newParentLength = parentAtom.length - metaLength;

                // If the meta atoms ancestor after the meta atom
                // removal only contains two blocks (i.e. name and length)
                // then it can also be removed.
                if(newParentLength == MPEG4_BOX_LENGTH*2) {
                    metaLength += newParentLength;
                    newParentLength = 0;
                }
                parentAtom.length = newParentLength;

                if(!childAtom.length) {
                    childAtom.parentAtom = nil;
                    NSMutableArray *children = parentAtom.childAtoms.mutableCopy;
                    [children removeObject:childAtom];
                    parentAtom.childAtoms = children;
                }

                childAtom = parentAtom;
                parentAtom = parentAtom.parentAtom;
            }
        }
    }
    allAtoms = self.allAtoms;

    NSFileManager *fileManager = NSFileManager.defaultManager;
    [fileManager createFileAtPath:path contents:[NSData data] attributes:nil];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    for(MPEG4Atom *atom in allAtoms) {
        NSRange lengthRange = NSMakeRange(atom.rangeToNextAtom.location, MPEG4_BOX_LENGTH);
        NSRange rangeFromAtomDataToNextAtom = NSMakeRange(lengthRange.location + MPEG4_BOX_LENGTH,
                                                          atom.rangeToNextAtom.length - MPEG4_BOX_LENGTH);
        // When the mdat atom has a length of zero that implies the length
        // should be to the end of the file.
        if (!atom.rangeToNextAtom.length && [atom.name isEqualToString:@"mdat"])
            rangeFromAtomDataToNextAtom.length = self.data.length - rangeFromAtomDataToNextAtom.location;

        // The atom length may have changed so write it out separately.
        // MPEG-4 is big endian so fix byte ordering
        uint32 bigEndianLength = CFSwapInt32HostToBig(atom.length);
        NSData *lengthData = [NSData dataWithBytes:&bigEndianLength
                                            length:MPEG4_BOX_LENGTH];
        [fileHandle writeData:lengthData];

        // If the meta atom is before the mdat atom we need to
        // recalculate the offsets in the stco atom.
        if(metaBeforeMdat && [atom.name isEqualToString:@"stco"]) {
            NSRange stcoNameRange = [MPEG4Atom nextBoxRange:lengthRange];
            // The stco atom follows the name with the version and flags,
            // table entries count and the table itself.
            NSRange stcoVersionAndFlagsRange = [MPEG4Atom nextBoxRange:stcoNameRange];
            NSRange stcoEntriesRange = [MPEG4Atom nextBoxRange:stcoVersionAndFlagsRange];
            NSRange stcoNameVersionFlagsAndEntriesRange = NSMakeRange(stcoNameRange.location,
                                                                      MPEG4_BOX_LENGTH*3);
            // The version and flags and table entries count will be unchanged so write them out.
            [fileHandle writeData:[self.data subdataWithRange:stcoNameVersionFlagsAndEntriesRange]];

            NSMutableData *newStcoEntries = NSMutableData.data;
            NSUInteger tableEntriesCount = [MPEG4File unsignedIntegerFromData:self.data
                                                                    withRange:stcoEntriesRange];
            NSRange chunkRange = [MPEG4Atom nextBoxRange:stcoEntriesRange];
            // Iterate through the table removing the now-removed
            // metadata atom length from each of the stco entries.
            // Each of these entries corresponds to an offset in the mdat atom.
            for(NSUInteger i=0; i < tableEntriesCount; i++) {
                uint32 mdatOffset = [MPEG4File unsignedIntegerFromData:self.data
                                                             withRange:chunkRange];
                mdatOffset -= metaLength;
                // MPEG-4 is big endian so fix byte ordering
                uint32 bigEndianOffset = CFSwapInt32HostToBig(mdatOffset);
                [newStcoEntries appendBytes:&bigEndianOffset length:chunkRange.length];
                chunkRange = [MPEG4Atom nextBoxRange:chunkRange];
            }

            // Write out the newly calculated stco table.
            [fileHandle writeData:newStcoEntries];
        }
        else {
            // For all other atoms we can just write out the name and data without modification.
            [fileHandle writeData:[self.data subdataWithRange:rangeFromAtomDataToNextAtom]];
        }
    }
    fprintf(stdout, "%s: wrote MPEG4 file without meta atom to: %s\n",
            NSProcessInfo.processInfo.processName.UTF8String, path.UTF8String);
}

- (void)printAtomNames {
    for(MPEG4Atom *atom in self.allAtoms)
        [atom printNameWithParents];
}

+ (NSArray*)descendentAtomsOf:(MPEG4Atom*)parentAtom
                     withName:(NSString*)name {
    NSMutableArray *foundAtoms = NSMutableArray.array;
    for(MPEG4Atom *atom in [MPEG4File descendentAtomsWithParent:parentAtom])
        if([atom.name isEqualToString:name])
            [foundAtoms addObject:atom];
    return foundAtoms;
}

+ (NSArray*)descendentAtomsWithParent:(MPEG4Atom*)parentAtom {
    NSMutableArray *atoms = NSMutableArray.array;
    [atoms addObject:parentAtom];
    for(MPEG4Atom *childAtom in parentAtom.childAtoms) {
        NSArray *childDescendantAtoms = [MPEG4File descendentAtomsWithParent:childAtom];
        if(childDescendantAtoms.count)
            [atoms addObjectsFromArray:childDescendantAtoms];
    }
    return atoms;
}

+ (uint32)unsignedIntegerFromData:(NSData*)data
                        withRange:(NSRange)range
{
    if(NSMaxRange(range) > data.length)
        return 0;
    uint32 bigEndianUnsignedInteger = 0;
    [data getBytes:&bigEndianUnsignedInteger range:range];
    // MPEG-4 is big endian so fix byte ordering
    return CFSwapInt32BigToHost(bigEndianUnsignedInteger);
}

+ (NSString*)asciiStringFromData:(NSData*)data
                       withRange:(NSRange)range
{
    if(NSMaxRange(range) > data.length)
        return @"";
    NSData *subdata = [data subdataWithRange:range];
    NSString *string = [NSString.alloc initWithData:subdata
                                           encoding:NSASCIIStringEncoding];
    return string;
}

- (NSArray*)allAtoms {
    NSMutableArray *allAtoms = NSMutableArray.array;
    for(MPEG4Atom *atom in self.topLevelAtoms) {
        NSArray *descendantAtoms = [MPEG4File descendentAtomsWithParent:atom];
        if(descendantAtoms.count)
            [allAtoms addObjectsFromArray:descendantAtoms];
    }
    return allAtoms;
}
@end
