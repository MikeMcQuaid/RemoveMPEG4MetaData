//
//  MPEG4Atom.h
//  RemoveMPEG4MetaData
//
//  Copyright (c) 2012 Mike McQuaid. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPEG4Atom : NSObject
- (id)initWithData:(NSData*)data
         andOffset:(NSUInteger)offset;
- (id)nextSiblingAtomFromData:(NSData*)data;
- (void)printNameWithParents;

+ (NSRange)nextBoxRange:(NSRange)currentAtomBoxRange;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic) NSUInteger location;
@property (nonatomic) uint32 length;
@property (nonatomic) id parentAtom;
@property (nonatomic, copy) NSArray *childAtoms;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) NSRange rangeToNextAtom;
@property (nonatomic, readonly) NSUInteger nextSiblingAtomLocation;
@property (nonatomic, readonly) NSUInteger nextAtomLocation;
@end
