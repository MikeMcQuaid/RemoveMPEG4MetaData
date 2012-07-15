//
//  MPEG4File.h
//  RemoveMPEG4MetaData
//
//  Copyright (c) 2012 Mike McQuaid. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPEG4Atom;

@interface MPEG4File : NSObject
- (id)initWithPath:(NSString*)path;
- (NSArray*)atomsWithName:(NSString*)name;
- (void)removeMetaDataAndWriteToFileName:(NSString*)path;
- (void)printAtomNames;

+ (NSArray*)descendentAtomsOf:(MPEG4Atom*)parentAtom
                     withName:(NSString*)name;
+ (NSArray*)descendentAtomsWithParent:(MPEG4Atom*)parentAtom;
+ (uint32)unsignedIntegerFromData:(NSData*)data
                        withRange:(NSRange)range;
+ (NSString*)asciiStringFromData:(NSData*)data
                  withRange:(NSRange)range;

@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSData *data;
@property (nonatomic, copy) NSArray *topLevelAtoms;
@property (nonatomic, readonly) NSArray *allAtoms;

// All data in MPEG4 files is in 4-byte blocks.
#define MPEG4_BOX_LENGTH 4
@end
