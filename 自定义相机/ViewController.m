//
//  ViewController.m
//  自定义相机
//
//  Created by 夏桂峰 on 15/12/1.
//  Copyright (c) 2015年 夏桂峰. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#define kWidth ([UIScreen mainScreen].bounds.size.width)
#define kHeight ([UIScreen mainScreen].bounds.size.height)

@interface ViewController ()

@property(nonatomic,strong)AVCaptureSession *session;
@property(nonatomic,strong)AVCaptureDeviceInput *input;
@property(nonatomic,strong)AVCaptureStillImageOutput *output;
@property(nonatomic,strong)AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic,strong)UIView *cameraView;
//拍照
@property(nonatomic,strong)UIButton *shutterBtn;
//对焦
@property(nonatomic,strong)UIView *focalReticule;
//焦距Button
@property(nonatomic,strong)UIButton *focalBtn;

@end

//焦距
static float kCameraScale=1.0;

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setUpSession];
    [self initCameraLayer];
    [self ceateUI];
    [self createFunctionalUI];
}
//开始任务
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
     [_session startRunning];
}
//停止任务
-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_session stopRunning];
}
//初始化抓取任务
-(void)setUpSession
{
    _session=[[AVCaptureSession alloc]init];
    AVCaptureDevice *device=nil;
    NSArray *devices=[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for(AVCaptureDevice *tmp in devices)
    {
        if(tmp.position==AVCaptureDevicePositionBack)
            device=tmp;
    }
    _input=[[AVCaptureDeviceInput alloc]initWithDevice:device error:nil];
    _output=[[AVCaptureStillImageOutput alloc]init];
    _output.outputSettings=@{AVVideoCodecKey:AVVideoCodecJPEG};
    if([_session canAddInput:_input])
        [_session addInput:_input];
    if([_session canAddOutput:_output])
        [_session addOutput:_output];
}
//初始化相机预览层
-(void)initCameraLayer
{
    _cameraView=[[UIView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:_cameraView];
    _previewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:_session];
    [_cameraView.layer setMasksToBounds:YES];
    [self.previewLayer setFrame:_cameraView.bounds];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [_cameraView.layer insertSublayer:self.previewLayer below:[[_cameraView.layer sublayers] objectAtIndex:0]];
}
//搭建UI
-(void)ceateUI
{
    //拍照按钮
    _shutterBtn=[[UIButton alloc]initWithFrame:CGRectMake(20, kHeight-60, 36, 48)];
    [_shutterBtn setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [_shutterBtn setImage:[UIImage imageNamed:@"camera_h"] forState:UIControlStateHighlighted];
    [self.view addSubview:_shutterBtn];
    [_shutterBtn addTarget:self action:@selector(shutter) forControlEvents:UIControlEventTouchUpInside];
    
    //对焦十字
    _focalReticule=[[UIView alloc]initWithFrame:CGRectMake(0, 0, 60, 60)];
    _focalReticule.backgroundColor=[UIColor clearColor];
    //十字
    UIView *line1=[[UIView alloc]initWithFrame:CGRectMake(0, 29.5, 60, 1)];
    line1.backgroundColor=[UIColor whiteColor];
    [_focalReticule addSubview:line1];
    
    UIView *line2=[[UIView alloc]initWithFrame:CGRectMake(29.5, 0, 1, 60)];
    line2.backgroundColor=[UIColor whiteColor];
    [_focalReticule addSubview:line2];
    [self.view addSubview:_focalReticule];
    //默认隐藏
    _focalReticule.hidden=YES;
    
    //点击屏幕对焦的手势
    UITapGestureRecognizer *foucusTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(foucus:)];
    [self.view addGestureRecognizer:foucusTap];
}
//功能性UI
-(void)createFunctionalUI
{
    //1x 2x 3x 4x焦距按钮
    _focalBtn=[[UIButton alloc]initWithFrame:CGRectMake(20, kHeight-110, 48, 36)];
    [_focalBtn setTitle:@"1x" forState:UIControlStateNormal];
    [_focalBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _focalBtn.backgroundColor=[UIColor clearColor];
    _focalBtn.layer.cornerRadius=10;
    _focalBtn.layer.borderColor=[UIColor whiteColor].CGColor;
    _focalBtn.layer.borderWidth=1.0;
    _focalBtn.transform=CGAffineTransformMakeRotation(M_PI_2);
    [_focalBtn addTarget:self action:@selector(adjustFocalDistance:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_focalBtn];
    CGRect frame=_focalBtn.frame;
    frame.origin.x=_shutterBtn.frame.origin.x;
    _focalBtn.frame=frame;
}
//调整焦距
-(void)adjustFocalDistance:(UIButton *)sender
{
    kCameraScale+=1.0;
    if(kCameraScale>4.0)
        kCameraScale=1.0;
    //改变焦距
    AVCaptureConnection *connect=[_output connectionWithMediaType:AVMediaTypeVideo];
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.2];
    [_focalBtn setTitle:[NSString stringWithFormat:@"%dx",(int)kCameraScale] forState:UIControlStateNormal];
    [_previewLayer setAffineTransform:CGAffineTransformMakeScale(kCameraScale, kCameraScale)];
    connect.videoScaleAndCropFactor=kCameraScale;
    [CATransaction commit];
}
//对焦
-(void)foucus:(UITapGestureRecognizer *)sender
{
    if(sender.state==UIGestureRecognizerStateRecognized)
    {
        CGPoint location=[sender locationInView:self.view];
        //对焦
        __weak typeof(self) weakSelf=self;
        [self focusOnPoint:location completionHandler:^{
            weakSelf.focalReticule.center=location;
            weakSelf.focalReticule.alpha=0.0;
            weakSelf.focalReticule.hidden=NO;
            [UIView animateWithDuration:0.3 animations:^{
                weakSelf.focalReticule.alpha=1.0;
            }completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    weakSelf.focalReticule.alpha=0.0;
                }];
            }];
        }];
    }
}
//对某一点对焦
-(void)focusOnPoint:(CGPoint)point completionHandler:(void(^)())completionHandler
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];;
    CGPoint pointOfInterest = CGPointZero;
    CGSize frameSize = self.view.bounds.size;
    pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
    
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        
        NSError *error;
        if ([device lockForConfiguration:&error])
        {
            
            if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance])
            {
                [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            }
            
            if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            {
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
                [device setFocusPointOfInterest:pointOfInterest];
            }
            
            if([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [device setExposurePointOfInterest:pointOfInterest];
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [device unlockForConfiguration];
            
            completionHandler();
        }
    }
    else
    {
        completionHandler();
    }
}
//拍照
-(void)shutter
{
    AVCaptureConnection *connect=[_output connectionWithMediaType:AVMediaTypeVideo];
    if(!connect)
    {
        NSLog(@"拍照失败");
        return;
    }
    __weak typeof(self) weakSelf=self;
    [_output captureStillImageAsynchronouslyFromConnection:connect completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if(imageDataSampleBuffer==NULL)
            return;
        NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image=[UIImage imageWithData:imageData];
        [self shutterSuccessAlert];
        //注意：正常情况，直接保存至相册就ok，这个方法下面的三个方法都可以不写。
        //我这里是为了要在图片上添加经纬度信息，海拔高度等，所以单独用imageView显示出来。
        //因此，接下来的三个方法你可以直接删去。
        //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        //显示拍到的图片
        [weakSelf showCapturedImageOnScreen:image];
        
    }];
}
//显示拍取的照片
-(void)showCapturedImageOnScreen:(UIImage *)capturedImage
{
    UIImageView *imv=[[UIImageView alloc]initWithFrame:self.view.bounds];
    imv.image=capturedImage;
    [self.view addSubview:imv];
    imv.userInteractionEnabled=YES;
    //需要在照片上添加经纬度，海拔，方位角，水平角，俯仰角，焦距放大倍率等信息，然后截取屏幕
    
    UIButton *cancelBtn=[[UIButton alloc]initWithFrame:CGRectMake(20, 100, 60, 40)];
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelBtn.backgroundColor=[UIColor clearColor];
    cancelBtn.layer.cornerRadius=5;
    cancelBtn.layer.borderColor=[UIColor whiteColor].CGColor;
    cancelBtn.layer.borderWidth=1.0;
    [cancelBtn addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.transform=CGAffineTransformMakeRotation(M_PI_2);
    [imv addSubview:cancelBtn];
    
    
    UIButton *saveBtn=[[UIButton alloc]initWithFrame:CGRectMake(20, kHeight-100, 60, 40)];
    [saveBtn setTitle:@"保存" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor=[UIColor clearColor];
    saveBtn.layer.cornerRadius=5;
    saveBtn.layer.borderColor=[UIColor whiteColor].CGColor;
    saveBtn.layer.borderWidth=1.0;
    [saveBtn addTarget:self action:@selector(save:) forControlEvents:UIControlEventTouchUpInside];
    saveBtn.transform=CGAffineTransformMakeRotation(M_PI_2);
    [imv addSubview:saveBtn];
}

//取消
-(void)cancel:(UIButton *)sender
{
    [sender.superview removeFromSuperview];
}
//保存
-(void)save:(UIButton *)sender
{
    UIImageView *imv=(UIImageView *)sender.superview;
    
    for(UIView *sub in sender.superview.subviews)
    {
        if([sub isKindOfClass:[UIButton class]])
            [sub removeFromSuperview];
    }
    UIGraphicsBeginImageContextWithOptions(imv.bounds.size, NO, 0.0);
    [imv.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *currentImage=UIGraphicsGetImageFromCurrentImageContext();
    //保存图片
    UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil);
    UIGraphicsEndImageContext();
    [imv removeFromSuperview];
}
//播放拍照音效
-(void)shutterSuccessAlert
{
    //播放音效
    SystemSoundID soundID;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sound.mp3" ofType:nil]],&soundID);
    //播放短音频
    AudioServicesPlaySystemSound(soundID);
    //增加震动效果
    //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}
//隐藏状态栏
-(BOOL)prefersStatusBarHidden
{
    return YES;
}

@end
