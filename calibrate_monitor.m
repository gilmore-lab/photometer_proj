function params = calibrate_monitor( varargin )
% calibrate_monitor -- calibrates video monitor luminance
%
% params = calibrate_monitor( [,param, value],...)
%
%   Takes a number of user defined parameters in the standard MATLAB
%   param, value pair format.  Shown below are the default values.
%
%   'photometer'        : 'il1700'  to add others, need new function
%   'scale_factor'      : 16        samples over 256 bit grayscale
%   'font_size'         : 24        font size for value, text display
%   'text_style'        : 1         boldface text
%   'manual_advance'    : 0         advances through grayscale levels
%   'display_value'     : 1         display recorded cd/m^2 value
%   'secs_bw_samples'   : 1         speed of patch display, data collection
%   'show_patches'      : 1         defaults to showing on this computer


%----   Dependencies
%
%   Calls:
%       Screen.m and other Psychophysics Toolbox routines.  The toolbox is
%       required for use under Mac OS X because of dependence on
%       SerialComm.m.  However, this may work without the toolbox installed
%       on Windows XP systems as MATLAB's Serial.m command is used.  The
%       program tests to see whether the Psychophysics Toolbox is
%       installed and whether the appropriate serial port command is
%       installed.

%----   History
%   081223  rog wrote initial portion.  Need to add actual display and
%           measurement portions.  Copied display portions from old
%           measure_monitor_gamma.m routine, but have not tested.
%

%----   Get parameter values from varargin
params = get_photometer_params( varargin );

%----   Is Psychtoolbox installed and in path?
params.ptb_status = exist('Screen');
if params.ptb_status ~=3
    disp(sprintf('[%s]: Psychophysics Toolbox not installed or in path.', mfilename) );
else
    disp(sprintf('[%s]: Psychophysics Toolbox installed.', mfilename) );
end

%----   On Mac OS X, need to have SerialComm.m in path even if
%       Psychophysics Toolbox is missing
if strcmp( params.comp, 'mac' )
    if ~exist('SerialComm')
        disp( sprintf('[%s]: SerialComm routine not in path. Terminating.', mfilename ) );
        return;
    else
        disp( sprintf('[%s]: SerialComm routine in path.', mfilename ) );
    end % if ~exist
else % on other platforms...
    if ~exist('serial')
        disp( sprintf('[%s]: Serial routine not in path. Terminating.', mfilename ) );
        return;
    else
        disp( sprintf('[%s]: Serial routine in path.', mfilename ) );
    end % if ~exist
end % if strcmp

%----   Assign function handle to selected photometer
%----       Is photometer handler function in path?
params.photometer_path = which( params.photometer );
if isempty( params.photometer_path )
    disp(sprintf('[%s]: %s photometer handler not installed or in path.', mfilename, params.photometer ) );
    return;
else
    disp(sprintf('[%s]: %s photometer handler installed.', mfilename, params.photometer ) );
    params.photometer_fh = str2func( params.photometer ); % Create file handle
end

%----   Check connection to selected photometer
[ params.photometer_status, params.photometer_error ] = params.photometer_fh('open');
if params.photometer_status
    disp(sprintf('[%s]: Error -- %s.', mfilename, params.photometer_error ) );
    return;
else
    disp(sprintf('[%s]: Connected to photometer %s.', mfilename, params.photometer) );
    [ params.photometer_status, params.photometer_error ] = params.photometer_fh('close');
end

lum = zeros( params.scale_factor, 1);
clut_index = zeros( params.scale_factor, 1 );

%----   Embed Psychophysics Toolbox routines in try/catch/end
if params.show_patches
    try
        %----   Open Screen
        AssertOpenGL;
        screens=Screen('Screens');
        screenNumber=max(screens);

        % Find the color values which correspond to white and black.
        white=WhiteIndex(screenNumber);
        black=BlackIndex(screenNumber);
        gray=(white+black)/2;
        if round(gray)==white
            gray=black;
        end

        %----   Generate clut indices
        clut_index  = linspace( black, white, params.scale_factor )';

        %----   Open window with black color
        w=Screen('OpenWindow',screenNumber, 0,[],32,2);
        Screen('FillRect',w, black);
        Screen('TextFont', w, 'Courier New');
        Screen('TextSize', w, params.font_size);
        Screen('TextStyle', w, params.text_style );
        Screen('Flip', w);

        %-----  Provide user instructions and start calibration
        Screen('FrameRect', w, white, [ 2 2 640 240 ], 2 );
        Screen('DrawText', w, 'Attach detector flush to screen.', 10, 10, white );
        Screen('DrawText', w, 'Hit any key to begin.', 10, 50, white );
        Screen('Flip', w);
        KbWait;
        keyIsDown = 0;
        while ~keyIsDown
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            WaitSecs(.001);
        end

        %----   Loop on clut index, measure luminance
        for m = 1:params.scale_factor

            %----   Fill window with current gray scale value
            curr_gray = clut_index( m );

            %----   Write gray value to screen
            Screen('FillRect', w, curr_gray);
            curr_contr_diff = curr_gray - gray;
            if curr_contr_diff < 0
                text_color = white;
            else
                text_color = black;
            end

            Screen('FrameRect', w, text_color, [ 2 2 640 240 ], 2 );
            Screen('DrawText', w, [ 'Gray value = ' num2str( curr_gray ) '/(' num2str(m) ' of '...
                num2str( params.scale_factor ) ')' ], 10, 10, text_color );
            Screen('Flip', w);

            %----   Wait for screen to change and photometer to settle
            [ params.photometer_status, params.photometer_error ] = params.photometer_fh('open');
            if params.photometer_status
                disp(sprintf('[%s]: %s', mfilename, params.photometer_error ) );
                break;
            end

            %----   If manual advance mode, hit key to capture value
            Screen('FrameRect', w, text_color, [ 2 2 640 240 ], 2 );
            Screen('DrawText', w, [ 'Gray value = ' num2str( curr_gray ) '/(' num2str(m) ' of '...
                num2str( params.scale_factor ) ')' ], 10, 10, text_color );
            if params.manual_advance
                Screen('DrawText', w, 'Hit key to capture reading.', 10, 100, text_color );
                Screen('Flip', w);
                KbWait;
                while ~keyIsDown
                    KbCheck;
                end;
            else
                WaitSecs( params.secs_bw_samples );
            end

            %----   Get luminance value
            Screen('FrameRect', w, text_color, [ 2 2 640 240 ], 2 );
            Screen('DrawText', w, [ 'Gray value = ' num2str( curr_gray ) '/(' num2str(m) ' of '...
                num2str( params.scale_factor ) ')' ], 10, 10, text_color );
            Screen('DrawText', w, 'Reading value.', 10, 100, text_color );
            [ params.photometer_status, params.photometer_error, value ] = params.photometer_fh('readl');
            if params.photometer_status
                disp(sprintf('[%s]: %s', mfilename, params.photometer_error ) );
                break;
            else
                lum(m) = str2double( value );
            end % if photometer_status

            Screen('FrameRect', w, text_color, [ 2 2 640 240 ], 2 );
            Screen('DrawText', w, [ 'Gray value = ' num2str( curr_gray ) '/(' num2str(m) ' of '...
                num2str( params.scale_factor ) ')' ], 10, 10, text_color );
            if params.display_value
                Screen('DrawText', w, [ 'Lum (cd/m2) = '  value ], 10, 200, text_color );
                Screen('Flip', w);
                WaitSecs(1);
            else
                Screen('DrawText', w, [ 'Wrote value to data.' ], 10, 200, text_color );
                Screen('Flip', w);
                WaitSecs(1);
            end

            %----   Close connection
            [ params.photometer_status, params.photometer_error ] = params.photometer_fh('close');
            if params.photometer_status
                disp(sprintf('[%s]: %s', mfilename, params.photometer_error ) );
                break;
            end

        end % for m

        %----   Clear screen
        Screen('CloseAll');
    catch
        params.photometer_fh('close');
        rethrow( lasterror );
        Screen('CloseAll');
    end % try/catch
end % if show_patches

Screen('CloseAll');

params.lum = lum;
params.clut_index = clut_index;

return

