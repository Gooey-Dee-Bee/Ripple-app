//
//  ViewController.m
//  Ripple-App
//
//  Created by William O'Connor on 4/22/15.
//  Copyright (c) 2015 Gooey Dee Bee. All rights reserved.
//

#import "ViewController.h"
#import "SCUI.h"
#import "DataManager.h"
#import "songCell.h"

@interface ViewController ()

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) NSMutableArray *tracks;
@property (nonatomic, strong) AVAudioPlayer *player;
@property(nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSDictionary *nowPlayingTrack;
@property (strong, nonatomic) NSMutableDictionary* screenSize;
@property (strong, nonatomic) UIImageView *albumCover;
@property (strong, nonatomic) NSMutableArray *albumCovers;
@property (strong, nonatomic) wboPlayerView* playerGui;
@property (strong, nonatomic) UIActivityIndicatorView* loading;
@property NSInteger nowPlayingTrackIndex;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *signInButton;
@property BOOL signedIn;

// TIMER
@property NSTimer *timer;
@property int time;
- (void) clock;
- (void) startTimer;
- (void) countup;
- (void) updateSlider;

@end

@implementation ViewController

-(NSMutableArray*)tracks
{
    if (!_tracks) {
        _tracks = [[NSMutableArray alloc] init];
    }
    return _tracks;
}

-(NSMutableArray*)albumCovers
{
    if (!_albumCovers) {
        _albumCovers = [[NSMutableArray alloc] init];
    }
    return _albumCovers;
}

-(NSMutableDictionary*)screenSize
{
    if (!_screenSize) {
        _screenSize = [[NSMutableDictionary alloc] init];
    }
    return _screenSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib
    
    self.nowPlayingTrackIndex = -1;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    NSNumber *height = [[NSNumber alloc] initWithDouble:screenHeight];
    NSNumber *width = [[NSNumber alloc] initWithDouble:screenWidth];
    NSLog(@"width: %@", width);
    
    self.screenSize[@"height"] = height;
    self.screenSize[@"width"] = width;
    
    [[NSUserDefaults standardUserDefaults] setObject:self.screenSize forKey:@"screen"];
    

    
    self.albumCover = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 64.0, [self.screenSize[@"width"] doubleValue], 200.0)];
    self.albumCover.hidden = YES;
    [self.view addSubview:self.albumCover];

//      PLAYER
    self.playerGui = [[wboPlayerView alloc] initWithFrame:CGRectMake(0.0, 184.0, [self.screenSize[@"width"] doubleValue], 80.0)];
    self.playerGui.hidden = YES;
    self.playerGui.delegate = self;
    [self.view addSubview:self.playerGui];
    
//      ACTIVITY INDICATOR
    self.loading = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    double x = [self.screenSize[@"width"] doubleValue]/2;
    self.loading.center = CGPointMake(x, 160.0);
    NSLog(@"center: %f", self.loading.center.x);
    self.loading.hidesWhenStopped = YES;
    [self.tableView addSubview:self.loading];
    [self.tableView bringSubviewToFront:self.loading];
    
    [self.loading startAnimating];
    
    // TABLEVIEW
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.frame = CGRectMake(0.0, 64.0, [self.screenSize[@"width"] doubleValue], [self.screenSize[@"height"] doubleValue]);
    self.tableView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
    self.view.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
    [self.tableView registerClass:[songCell class] forCellReuseIdentifier:@"cell"];
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:refreshControl];
    [self.view addSubview:self.tableView];
    
    // NAV BAR
    self.navigationItem.title = @"Ripple";
    [self.navigationController.navigationBar setTitleTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [UIColor whiteColor], NSForegroundColorAttributeName,
      [UIFont fontWithName:@"Cookie" size:44],
       NSFontAttributeName, nil]];
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0x48/255.0 green:0x98/255.0 blue:0xBD/255.0 alpha:1.0];
    
    // NAV BAR BUTTON
//    [self.signInButton setTintColor:[UIColor whiteColor]];
    [self.signInButton setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont fontWithName:@"Poiret One" size:18.0], NSFontAttributeName,
                                        [UIColor whiteColor], NSForegroundColorAttributeName,
                                        nil] 
                              forState:UIControlStateNormal];
    
    // check for location
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"latitude"]) {
        [self setUpLocation];
    }
    else {
        NSLog(@"Location already set");
        [self loadSongs];
    }
    
    // check for signed in
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"email"] length] > 3) {
        NSLog(@"email: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"email"]);
        self.signedIn = YES;
        self.signInButton.title = @"Account";
    }
    else {
        self.signedIn = NO;
        self.signInButton.title = @"Sign In";
    }
    
    [self.player prepareToPlay];
    
}

- (void) setUpLocation {
    //LOCATION
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLLocationAccuracyThreeKilometers;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
    
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager startUpdatingLocation];
    }
//    [self.locationManager stopUpdatingLocation];
}

-(void) locationManager: (CLLocationManager *)manager didUpdateToLocation: (CLLocation *) newLocation
           fromLocation: (CLLocation *) oldLocation {
    CLLocation *location = newLocation;
    // Configure the new event with information from the location
    CLLocationCoordinate2D coordinate = [location coordinate];
    
    float longitude = coordinate.longitude;
    float latitude = coordinate.latitude;
    
    int lat = (int) latitude;
    int lon = (int) longitude;
    
    NSString *latS = [NSString stringWithFormat:@"%i", lat];
    NSString *lonS = [NSString stringWithFormat:@"%i", lon];
    
    [[NSUserDefaults standardUserDefaults] setObject:latS forKey:@"latitude"];
    [[NSUserDefaults standardUserDefaults] setObject:lonS forKey:@"longitude"];
    [self.locationManager stopUpdatingLocation];
    
    [self loadSongs];
    
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
        {
            // do some error handling
        }
            break;
        default:{
            [self.locationManager startUpdatingLocation];
        }
            break;
    }
}

- (void) loadSongs {
    NSMutableDictionary *location = [[NSMutableDictionary alloc] init];
    location[@"latitude"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"latitude"];
    location[@"longitude"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"longitude"];
    
    // reset arrays
    [self.tracks removeAllObjects];
    [self.albumCovers removeAllObjects];
    
    // HARDCODE LOCATION
//    NSNumber *tempNumber = [[NSNumber alloc] initWithDouble:32.846];
//    location[@"latitude"] = tempNumber;
//    NSNumber *tempNumber2 = [[NSNumber alloc] initWithDouble:-96.7837];
//    location[@"longitude"] = tempNumber2;
    
    NSDictionary* songs = [DataManager getSongList:location];
    NSLog(@"Got the song IDs");
    
    for (NSDictionary* song_id in songs) {
        NSDictionary* track = [DataManager getTrackInfo:song_id[@"song_id"]];
        [self.tracks addObject: track];
        
        
        
        // YOOO
        UIImage* albumCoverImage = [UIImage imageNamed:@"NowPlaying.png"];
        if (![track[@"artwork_url"] isEqual:[NSNull null]] && [track[@"artwork_url"] length] > 0){
            NSString* url = [track[@"artwork_url"] stringByReplacingOccurrencesOfString:@"large"                                                        withString:@"crop"];
            albumCoverImage = [UIImage imageWithData:
                                        [NSData dataWithContentsOfURL:
                                         [NSURL URLWithString: url]]];
        }
        
        [self.albumCovers addObject:albumCoverImage];
    }
    NSLog(@"Got the actual songs");
    
    self.tracks = [[[[self.tracks copy] reverseObjectEnumerator] allObjects] mutableCopy];
    self.albumCovers = [[[[self.albumCovers copy] reverseObjectEnumerator] allObjects] mutableCopy];
    [self.loading stopAnimating];
    [self.tableView reloadData];
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"error: %@", error);
    UIAlertView* noLocationAlert = [[UIAlertView alloc] initWithTitle:@"Could not get your location" message:@"Unfortunately, Ripple was not able to detect your location. This is a location-based app, so it will not work without that information. Please try again later." delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
    [noLocationAlert show];
    
    [self.locationManager stopUpdatingLocation];
    
    [self loadSongs];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//     TABLEVIEW

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.tracks count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    songCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    NSDictionary *track = [self.tracks objectAtIndex:indexPath.row];
//    NSLog(@"Track: %@", track);
    [cell setData:track];
    
    //to change background color of selected cell
    if (indexPath.row == self.nowPlayingTrackIndex) {
        cell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
    }
    else {
        cell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *track = [self.tracks objectAtIndex:indexPath.row];
    NSLog(@"track: %@", track[@"title"]);
    [self.timer invalidate];
    
    float tableViewHeight = [self.screenSize[@"height"] floatValue] - 264.0;
    self.tableView.frame = CGRectMake(0, 264.0, [self.screenSize[@"width"] doubleValue], tableViewHeight);
    
    //loader
    double x = [self.screenSize[@"width"] doubleValue]/2;
    self.loading.center = CGPointMake(x, 100.0);
    [self.albumCover addSubview:self.loading];
    [self.albumCover bringSubviewToFront:self.loading];
    [self.loading startAnimating];
    
    if (self.tableView.frame.origin.y == 264.0) {
        self.albumCover.hidden = NO;
        self.playerGui.hidden = NO;
        self.playerGui.playButton.hidden = YES;
        self.playerGui.pauseButton.hidden = NO;
    }
    else {
        NSLog(@"%f", self.tableView.frame.origin.y);
    }
    
    
    // PLAY SONG
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
    self.nowPlayingTrackIndex = indexPath.row;
    NSLog(@"index path: %ld", self.nowPlayingTrackIndex);
    
    [self playSong:track];
}

-(void)selectRow:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    self.nowPlayingTrack = [self.tracks objectAtIndex:indexPath.row];
    NSLog(@"track: %@", self.nowPlayingTrack[@"title"]);
    [self.timer invalidate];
    
    float tableViewHeight = [self.screenSize[@"height"] floatValue] - 264.0;
    self.tableView.frame = CGRectMake(0, 264.0, [self.screenSize[@"width"] doubleValue], tableViewHeight);
    
    //loader
    double x = [self.screenSize[@"width"] doubleValue]/2;
    self.loading.center = CGPointMake(x, 100.0);
    [self.albumCover addSubview:self.loading];
    [self.albumCover bringSubviewToFront:self.loading];
    [self.loading startAnimating];
    
    if (self.tableView.frame.origin.y == 264.0) {
        self.albumCover.hidden = NO;
        self.playerGui.hidden = NO;
        self.playerGui.playButton.hidden = YES;
        self.playerGui.pauseButton.hidden = NO;
    }
    else {
        NSLog(@"%f", self.tableView.frame.origin.y);
    }
    
    
    // PLAY SONG
    songCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
    self.nowPlayingTrackIndex = indexPath.row;
    NSLog(@"index path track: %@", self.tracks[self.nowPlayingTrackIndex][@"title"]);
    
    
    [self playSong:self.nowPlayingTrack];
}


-(void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
}

-(void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // STYLE
    songCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.selected = NO;
//    cell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
}

-(void)deselectRow:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // STYLE
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

- (void)refresh:(UIRefreshControl *)refreshControl {
    //MAINTAIN PROPER HIGHLIGHTING
    NSInteger oldNumSongs = [self.tracks count];
    [self loadSongs];
    NSInteger offset = 0;
    if (self.nowPlayingTrackIndex > -1) { // a song is playing
        offset = [self.tracks count] - oldNumSongs;
    }
    self.nowPlayingTrackIndex += offset;
    [self.tableView reloadData];
    
    // CELL COLORS
    // paths
    NSIndexPath *oldCellPath = [NSIndexPath indexPathForRow:oldNumSongs inSection:0];
    NSIndexPath *newCellPath = [NSIndexPath indexPathForRow:[self.tracks count] inSection:0];
    // cells
    UITableViewCell *oldCell = [self.tableView cellForRowAtIndexPath:oldCellPath];
    UITableViewCell *newCell = [self.tableView cellForRowAtIndexPath:newCellPath];
    //colors
    newCell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
    oldCell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
    
    [refreshControl endRefreshing];
}

// TIMER

- (void) updateSlider
{
    [self.playerGui.trackProgressSlider setValue: self.player.currentTime animated:YES];
}

- (void) startTimer
{
    self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(countup) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void) clock
{
}

- (void) countup
{
    [self.playerGui.trackProgressSlider setValue:self.player.currentTime animated:YES];
    [self.playerGui setSongDuration:self.playerGui.trackProgressSlider.value];
    [self.loading stopAnimating];
    
    if (self.player.currentTime > self.player.duration-1) {
        [self.player prepareToPlay];
        [self.timer invalidate];
        if (self.nowPlayingTrackIndex < self.tracks.count - 1) {
            [self playNextSong];
        }
        else {
            NSIndexPath *thisSongCellPath = [NSIndexPath indexPathForRow:self.nowPlayingTrackIndex+1 inSection:0];
            [self.tableView deselectRowAtIndexPath:thisSongCellPath animated:YES];
//            UITableViewCell* thisSongCell = [self.tableView cellForRowAtIndexPath:thisSongCellPath];
//            thisSongCell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
        }
    }
}

// DELEGATE METHODS

- (void) playButtonPressed
{
    NSLog(@"Play");
    
    [self.player play];
}

-(void) pauseButtonPressed
{
    NSLog(@"Pause");
    [self.player pause];
}

- (void) navigateInSong:(float)newTime
{
    [self.player setCurrentTime:newTime];
    
    // MPMediaPlayer Duration update
     NSMutableDictionary *playInfo = [NSMutableDictionary dictionaryWithDictionary:[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo];
    NSNumber *position = [NSNumber numberWithFloat:self.player.currentTime];
    [playInfo setObject:position forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = playInfo;
}

- (void) playSong: (NSDictionary*)track
{
    NSURL *trackURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.soundcloud.com/tracks/%@/stream?client_id=%@", track[@"id"], kClientId]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:trackURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // self.player is strong property
        self.player = [[AVAudioPlayer alloc] initWithData:data error:nil];
        
        
        //get your app's audioSession singleton object
        AVAudioSession* session = [AVAudioSession sharedInstance];
        
        //error handling
        BOOL success;
        NSError* session_error;
        
        //set the audioSession category.
        //Needs to be Record or PlayAndRecord to use audioRouteOverride:
        
        success = [session setCategory:AVAudioSessionCategoryPlayback
                                 error:&session_error];
        
        if (!success)  NSLog(@"AVAudioSession error setting category:%@",session_error);
        
        //set the audioSession override
//        success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
//                                             error:&error];
        if (!success)  NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",session_error);
        
        //activate the audio session
        success = [session setActive:YES error:&session_error];
        if (!success) NSLog(@"AVAudioSession error activating: %@",session_error);
        else NSLog(@"audioSession active");
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
        
        [self.player play];
        
        // MEDIA PLAYER
        UIImage *albumArtImg = self.albumCovers[self.nowPlayingTrackIndex];
        MPMediaItemArtwork* albumArt = [[MPMediaItemArtwork alloc] initWithImage:albumArtImg];
        
        NSString* artist = @"";
        if (![track[@"label_name"] isEqual:[NSNull null]] && [track[@"label_name"] length] > 0){
            artist = track[@"label_name"];
        }
        else {
            artist = track[@"user"][@"permalink"];
        }
        NSNumber* duration = [NSNumber numberWithFloat:self.player.duration];
        
        NSDictionary *info = @{ MPMediaItemPropertyArtist: artist,
                                MPMediaItemPropertyAlbumTitle: @"",
                                MPMediaItemPropertyTitle: track[@"title"],
                                MPMediaItemPropertyPlaybackDuration: duration,
                                MPMediaItemPropertyArtwork: albumArt
                                };
        
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
        
        // TRACK PROGRESS
        [self startTimer];
        self.playerGui.trackProgressSlider.maximumValue = self.player.duration;
        self.playerGui.trackProgressSlider.minimumValue = 0;
    }];
    
    [task resume];
    
    // PREPARE NEXT SONG
    
    self.playerGui.nowPlayingSongNameLabel.text = track[@"title"];
    self.albumCover.image = self.albumCovers[self.nowPlayingTrackIndex];
}

- (void) playNextSong
{
    // deselect the last one
    NSIndexPath *lastSongCellPath = [NSIndexPath indexPathForRow:self.nowPlayingTrackIndex inSection:0];
    [self deselectRow:self.tableView didDeselectRowAtIndexPath:lastSongCellPath];
    
    // select next cell
    NSLog(@"nextTrack: %@", self.tracks[self.nowPlayingTrackIndex+1][@"title"]);
    NSIndexPath *thisSongCellPath = [NSIndexPath indexPathForRow:(self.nowPlayingTrackIndex+1) inSection:0];
    [self selectRow:self.tableView didSelectRowAtIndexPath:thisSongCellPath];
    

    
    
    // old stuff
//    self.nowPlayingTrackIndex += 1;
//    
//    // adjust cell selected -- THIS AINT WORKIN
//    
//    // set last song to regular background
//    NSIndexPath *lastSongCellPath = [NSIndexPath indexPathForRow:(self.nowPlayingTrackIndex-1) inSection:0];
//    UITableViewCell* lastSongCell = [self.tableView cellForRowAtIndexPath:lastSongCellPath];
//    lastSongCell.contentView.backgroundColor = [UIColor colorWithRed:0x1F/255.0 green:0x32/255.0 blue:0x4D/255.0 alpha:1.0];
//    
//    // set next song to selected background
////    NSIndexPath *thisSongCellPath = [NSIndexPath indexPathForRow:self.nowPlayingTrackIndex inSection:0];
////    UITableViewCell* thisSongCell = [self.tableView cellForRowAtIndexPath:thisSongCellPath];
////    thisSongCell.contentView.backgroundColor = [UIColor colorWithRed:0x59/255.0 green:0x69/255.0 blue:0x80/255.0 alpha:1.0];
//    
//    // play the song
//    [self playSong:self.tracks[self.nowPlayingTrackIndex]];
    
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    //if it is a remote control event handle it correctly
    if (event.type == UIEventTypeRemoteControl)
    {
        if (event.subtype == UIEventSubtypeRemoteControlPlay)
        {
            [self playButtonPressed];
            [self.playerGui togglePlayButton];
        }
        else if (event.subtype == UIEventSubtypeRemoteControlPause)
        {
            [self pauseButtonPressed];
            [self.playerGui togglePlayButton];
        }
        else if (event.subtype == UIEventSubtypeRemoteControlNextTrack)
        {
            [self pauseButtonPressed];
            [self playNextSong];
//            if (self.nowPlayingTrackIndex < [self.tracks count]) {
//                NSIndexPath* nextSongPath = [NSIndexPath indexPathForRow:(self.nowPlayingTrackIndex+1) inSection:0];
//                [self selectRow:self.tableView didSelectRowAtIndexPath:nextSongPath];
//            }
        }
        else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack)
        {
            [self pauseButtonPressed];
            if (self.nowPlayingTrackIndex > 0) {
                NSIndexPath* prevSongPath = [NSIndexPath indexPathForRow:(self.nowPlayingTrackIndex-1) inSection:0];
                [self selectRow:self.tableView didSelectRowAtIndexPath:prevSongPath];
            }
        }
    }
}

- (IBAction)signInButtonPressed:(UIBarButtonItem *)sender {
    if ([self.signInButton.title isEqualToString:@"Sign In"]) {
        [self performSegueWithIdentifier:@"signInSegue" sender:self];
    }
    else {
        [self performSegueWithIdentifier:@"accountSegue" sender:self];
    }
}

@end
