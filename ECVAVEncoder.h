/* Copyright (c) 2011, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import <libavformat/avformat.h>

// Models/Storages
#import "ECVStorage.h"

// Models/Video
@class ECVVideoFrame;

// Models
@class ECVPixelBufferConverter;

@interface ECVAVEncoder : NSObject
{
	@private
	AVFormatContext *_formatCtx;
	CFMutableDictionaryRef _encoderByStorage;
	NSData *_header;
}

- (id)initWithStorages:(NSArray *)storages;

- (NSString *)MIMEType;
- (NSData *)header;
- (NSData *)encodedDataWithVideoFrame:(ECVVideoFrame *)frame;

@end

@interface ECVStreamEncoder : NSObject
{
	@private
	ECVAVEncoder *_encoder;
	ECVStorage *_storage;
	AVFormatContext *_formatCtx;
	AVStream *_stream;
}

- (id)initWithEncoder:(ECVAVEncoder *)encoder storage:(id)storage;

@property(readonly) ECVAVEncoder *encoder;
@property(readonly) id storage;

@property(readonly) AVFormatContext *formatContext;
@property(readonly) AVStream *stream;
@property(readonly) AVCodecContext *codecContext;
@property(readonly) AVCodec *codec;

- (void)lockFormatContext;
- (NSData *)unlockFormatContext;

@end

@interface ECVVideoStreamEncoder : ECVStreamEncoder
{
	@private
	ECVPixelBufferConverter *_converter;
	uint8_t *_convertedBuffer;
	NSUInteger _frameRepeatCount;
}

- (NSData *)encodedDataWithVideoFrame:(ECVVideoFrame *)frame;

@end

@interface ECVStorage(ECVEncoding)

- (ECVStreamEncoder *)streamEncoderForEncoder:(ECVAVEncoder *)encoder;

@end