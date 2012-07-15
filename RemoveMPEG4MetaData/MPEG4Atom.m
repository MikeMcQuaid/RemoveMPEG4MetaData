//
//  MPEG4Atom.m
//  RemoveMPEG4MetaData
//
//  Copyright (c) 2012 Mike McQuaid. All rights reserved.
//

#import "MPEG4Atom.h"
#import "MPEG4File.h"

@implementation MPEG4Atom
@synthesize name = _name;
@synthesize location = _location;
@synthesize length = _length;
@synthesize parentAtom = _parentAtom;
@synthesize childAtoms = _childAtoms;

- (id)initWithData:(NSData*)data
         andOffset:(NSUInteger)offset {
    self = super.init;
    if(!self)
        return nil;

    _location = offset;

    // Every atom starts with the length block
    NSRange atomLengthRange = NSMakeRange(self.location, MPEG4_BOX_LENGTH);
    _length = [MPEG4File unsignedIntegerFromData:data
                                       withRange:atomLengthRange];

    // Every atom follows the length with the name block
    NSRange atomNameRange = [MPEG4Atom nextBoxRange:atomLengthRange];
    NSString *atomName = [MPEG4File asciiStringFromData:data
                                              withRange:atomNameRange];

    // This test assumes that if the name block consists only of
    // 4 lowercase ASCII characters then it is a valid name.
    NSCharacterSet *invalidAtomNameCharacters = [NSCharacterSet.lowercaseLetterCharacterSet invertedSet];
    atomName = [atomName stringByTrimmingCharactersInSet:invalidAtomNameCharacters];
    if(atomName.length != MPEG4_BOX_LENGTH)
        return nil;
    _name = atomName;

    // If an atom's name is immediately followed by another length and name and
    // the atom's length is at least 4 blocks (16 bytes) then the following atom
    // (if valid) is a child of the current atom.
    // If not, the remainder of the atom's length is data.
    NSMutableArray *atomChildren = NSMutableArray.array;
    NSUInteger currentLocation = atomNameRange.location + MPEG4_BOX_LENGTH;
    while (currentLocation < self.nextSiblingAtomLocation) {
        MPEG4Atom *childAtom = [MPEG4Atom.alloc initWithData:data
                                                   andOffset:currentLocation];
        if(!childAtom)
            break;

        childAtom.parentAtom = self;
        [atomChildren addObject:childAtom];
        if (childAtom.length)
            currentLocation += childAtom.length;
        else
            currentLocation += MPEG4_BOX_LENGTH*2;
    }
    _childAtoms = atomChildren;

    return self;
}

- (id)nextSiblingAtomFromData:(NSData*)data
{
    if(self.nextSiblingAtomLocation >= data.length)
        return nil;
    return [MPEG4Atom.alloc initWithData:data
                               andOffset:self.nextSiblingAtomLocation];
}

- (void)printNameWithParents {
    MPEG4Atom *parent = self.parentAtom;
    NSMutableString *prefix = NSMutableString.string;
    while (parent) {
        [prefix insertString:@"." atIndex:0];
        [prefix insertString:parent.name atIndex:0];
        parent = parent.parentAtom;
    }

    fprintf(stdout, "name: %s%s\n", prefix.UTF8String, self.name.UTF8String);
}

+ (NSRange)nextBoxRange:(NSRange)currentAtomBoxRange
{
    NSUInteger nextAtomBoxLocation = currentAtomBoxRange.location + currentAtomBoxRange.length;
    return NSMakeRange(nextAtomBoxLocation, MPEG4_BOX_LENGTH);
}

- (NSRange)range
{
    return NSMakeRange(self.location, self.length);
}

- (NSRange)rangeToNextAtom
{
    NSUInteger lengthToNextAtom = self.nextAtomLocation - self.location;
    return NSMakeRange(self.location, lengthToNextAtom);
}

- (NSUInteger)nextSiblingAtomLocation
{
    return self.location + self.length;
}

- (NSUInteger)nextAtomLocation
{
    if(!self.childAtoms.count)
        return self.nextSiblingAtomLocation;

    return [[self.childAtoms objectAtIndex:0] location];
}
@end
