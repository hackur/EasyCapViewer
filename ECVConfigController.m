/* Copyright (c) 2009, Ben Trask
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
#import "ECVConfigController.h"

// Models
#import "ECVCaptureDocument.h"
#import "ECVCaptureDevice.h"
#import "ECVVideoFormat.h"
#import "ECVDeinterlacingMode.h"

// Other Sources
#if defined(ECV_ENABLE_AUDIO)
#import "ECVAudioDevice.h"
#endif
#import "ECVFoundationAdditions.h"

@interface ECVConfigController(Private)

- (void)_snapSlider:(NSSlider *)slider;

@end

@implementation ECVConfigController

#pragma mark +ECVConfigController

+ (id)sharedConfigController
{
	static ECVConfigController *c;
	if(!c) c = [[self alloc] init];
	return [[c retain] autorelease];
}

#pragma mark -ECVConfigController

- (IBAction)changeFormat:(id)sender
{
	[[_captureDocument videoSource] setVideoFormat:[[sender selectedItem] representedObject]];
}
- (IBAction)changeSource:(id)sender
{
	[[_captureDocument videoSource] setVideoSourceObject:[[sender selectedItem] representedObject]];
}
- (IBAction)changeDeinterlacing:(id)sender
{
	[[_captureDocument videoSource] setDeinterlacingMode:[ECVDeinterlacingMode deinterlacingModeWithType:[sender selectedTag]]];
}
- (IBAction)changeBrightness:(id)sender
{
	[self _snapSlider:sender];
	[[_captureDocument videoSource] setBrightness:[sender doubleValue]];
}
- (IBAction)changeContrast:(id)sender
{
	[self _snapSlider:sender];
	[[_captureDocument videoSource] setContrast:[sender doubleValue]];
}
- (IBAction)changeSaturation:(id)sender
{
	[self _snapSlider:sender];
	[[_captureDocument videoSource] setSaturation:[sender doubleValue]];
}
- (IBAction)changeHue:(id)sender
{
	[self _snapSlider:sender];
	[[_captureDocument videoSource] setHue:[sender doubleValue]];
}

#pragma mark -

- (IBAction)changeAudioInput:(id)sender
{
	[_captureDocument setAudioInput:[[sender selectedItem] representedObject]];
}
- (IBAction)changeUpconvertsFromMono:(id)sender
{
	[_captureDocument setUpconvertsFromMono:NSOnState == [sender state]];
}
- (IBAction)changeVolume:(id)sender
{
	[_captureDocument setVolume:[sender doubleValue]];
	[_captureDocument setMuted:NO];
}

#pragma mark -

- (ECVCaptureDocument *)captureDocument
{
	return _captureDocument;
}
- (void)setCaptureDocument:(ECVCaptureDocument *const)c
{
	[_captureDocument ECV_removeObserver:self name:ECVCaptureDeviceVolumeDidChangeNotification];
	_captureDocument = c;
	[_captureDocument ECV_addObserver:self selector:@selector(volumeDidChange:) name:ECVCaptureDeviceVolumeDidChangeNotification];
	[self volumeDidChange:nil];

	if(![self isWindowLoaded]) return;

	ECVCaptureDevice *const captureDevice = [_captureDocument videoSource];

	[sourcePopUp removeAllItems];
	if([captureDevice respondsToSelector:@selector(allVideoSourceObjects)]) for(id const videoSourceObject in [captureDevice allVideoSourceObjects]) {
		if([NSNull null] == videoSourceObject) {
			[[sourcePopUp menu] addItem:[NSMenuItem separatorItem]];
			continue;
		}
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[captureDevice localizedStringForVideoSourceObject:videoSourceObject] action:NULL keyEquivalent:@""] autorelease];
		[item setRepresentedObject:videoSourceObject];
		[item setEnabled:[captureDevice isValidVideoSourceObject:videoSourceObject]];
		[item setIndentationLevel:[captureDevice indentationLevelForVideoSourceObject:videoSourceObject]];
		[[sourcePopUp menu] addItem:item];
	}
	[sourcePopUp setEnabled:[captureDevice respondsToSelector:@selector(videoSourceObject)]];
	if([sourcePopUp isEnabled]) [sourcePopUp selectItemAtIndex:[sourcePopUp indexOfItemWithRepresentedObject:[captureDevice videoSourceObject]]];

	NSSet *const formats = [captureDevice supportedVideoFormats];
	[formatPopUp setMenu:[ECVVideoFormat menuWithVideoFormats:formats]];
	[formatPopUp setEnabled:[formats count] > 0];
	if([formatPopUp isEnabled]) [formatPopUp selectItemAtIndex:[formatPopUp indexOfItemWithRepresentedObject:[captureDevice videoFormat]]];

	[deinterlacePopUp selectItemWithTag:[[captureDevice deinterlacingMode] deinterlacingModeType]];
	[deinterlacePopUp setEnabled:!!captureDevice];

	[brightnessSlider setEnabled:[captureDevice respondsToSelector:@selector(brightness)]];
	[contrastSlider setEnabled:[captureDevice respondsToSelector:@selector(contrast)]];
	[saturationSlider setEnabled:[captureDevice respondsToSelector:@selector(saturation)]];
	[hueSlider setEnabled:[captureDevice respondsToSelector:@selector(hue)]];
	[brightnessSlider setDoubleValue:[brightnessSlider isEnabled] ? [captureDevice brightness] : 0.5f];
	[contrastSlider setDoubleValue:[contrastSlider isEnabled] ? [captureDevice contrast] : 0.5f];
	[saturationSlider setDoubleValue:[saturationSlider isEnabled] ? [captureDevice saturation] : 0.5f];
	[hueSlider setDoubleValue:[hueSlider isEnabled] ? [captureDevice hue] : 0.5f];
	[self _snapSlider:brightnessSlider];
	[self _snapSlider:contrastSlider];
	[self _snapSlider:saturationSlider];
	[self _snapSlider:hueSlider];

	[upconvertsFromMonoSwitch setEnabled:[_captureDocument respondsToSelector:@selector(upconvertsFromMono)]];
	[upconvertsFromMonoSwitch setState:[upconvertsFromMonoSwitch isEnabled] && [_captureDocument upconvertsFromMono]];

	[self audioHardwareDevicesDidChange:nil];
	[audioSourcePopUp setEnabled:!!_captureDocument];
}

#pragma mark -

- (void)audioHardwareDevicesDidChange:(NSNotification *)aNotif
{
	[audioSourcePopUp removeAllItems];
	NSMenuItem *const nilItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Input", nil) action:NULL keyEquivalent:@""] autorelease];
	[[audioSourcePopUp menu] addItem:nilItem];
	ECVAudioInput *const preferredInput = [[_captureDocument videoSource] builtInAudioInput];
	if(preferredInput) {
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[preferredInput name] action:NULL keyEquivalent:@""] autorelease];
		[item setRepresentedObject:preferredInput];
		[[audioSourcePopUp menu] addItem:item];
	}
	NSMenuItem *const separator = [NSMenuItem separatorItem];
	[[audioSourcePopUp menu] addItem:separator];
	BOOL hasAdditionalItems = NO;
	for(ECVAudioInput *const input in [ECVAudioInput allDevices]) {
		if(BTEqualObjects(input, preferredInput)) continue;
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[input name] action:NULL keyEquivalent:@""] autorelease];
		[item setRepresentedObject:input];
		[[audioSourcePopUp menu] addItem:item];
		hasAdditionalItems = YES;
	}
	if(!hasAdditionalItems) [[audioSourcePopUp menu] removeItem:separator];
	ECVAudioInput *const input = [_captureDocument audioInput];
	[audioSourcePopUp selectItemAtIndex:input ? [audioSourcePopUp indexOfItemWithRepresentedObject:input] : 0];
}
- (void)volumeDidChange:(NSNotification *)aNotif
{
	if(![self isWindowLoaded]) return;
	BOOL const volumeSupported = [_captureDocument respondsToSelector:@selector(volume)];
	[volumeSlider setEnabled:volumeSupported];
	if(volumeSupported) [volumeSlider setDoubleValue:[_captureDocument isMuted] ? 0.0f : [_captureDocument volume]];
	else [volumeSlider setDoubleValue:1.0f];
}

#pragma mark -ECVConfigController(Private)

- (void)_snapSlider:(NSSlider *)slider
{
	if(ABS([slider doubleValue] - 0.5f) < 0.03f) [slider setDoubleValue:0.5f];
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSPanel *const w = (NSPanel *)[self window];
	[w setBecomesKeyOnlyIfNeeded:YES];
	[w setCollectionBehavior:NSWindowCollectionBehaviorFullScreenAuxiliary];
	[[ECVAudioDevice class] ECV_addObserver:self selector:@selector(audioHardwareDevicesDidChange:) name:ECVAudioHardwareDevicesDidChangeNotification];
	[self setCaptureDocument:_captureDocument];
}
- (NSString *)windowFrameAutosaveName
{
	return NSStringFromClass([self class]);
}

#pragma mark -NSObject

- (id)init
{
	return [super initWithWindowNibName:@"ECVConfig"];
}
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end
