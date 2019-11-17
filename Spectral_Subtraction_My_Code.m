%%
%This code performs spectral subtraction for speech enhancement as given in [1]. It takes
%as input the name of the noisy file, the name of the enhanced file, the
%value of factor alpha at 0 dB as desired (given as alpha_o) which is
%either 3 or 4, the value of beta (the spectral floor) which is positive but 
%beta <<1. It also takes gamma (exponent of power spectrum) as input, thus allowing user
%to select gamma which is less than 1 and can create more spectral change.
%Also, it takes the normalization factor as input to improve level of
%processed signal.
%By changing values of alpha and beta, we can attenuate musical 
%noise and broadband noise as required while retaining speech intelligibility.

%  References:
%   [1] Berouti, M., Schwartz, M., and Makhoul, J. (1979). Enhancement of speech 
%       corrupted by acoustic noise. Proc. IEEE Int. Conf. Acoust., Speech, 
%       Signal Processing, 208-211.
%  
%  Resources used:
%
%   [1] Loizou, P.C., 2013. Speech enhancement: theory and practice. CRC press.
%   [2] Function deframe_sig taken from this source: https://raw.githubusercontent.com/jameslyons/spl_featgen/master/deframe_sig.m
%   [3] Help taken from this source: https://gist.github.com/jameslyons/554325efb2c05da15b31#file-spectral_subtraction_demo-m
   

%% Calling the function that performs spectral subtraction
Spectral_Subtraction_perform_1('noisy_train.wav',3,0.001,0.5,5,'clean_train.wav');


function Spectral_Subtraction_perform_1(noisy_filename,alpha_o,beta,gamma,Norm_G,enhanced_filename)

%% Read the input audio file and apply overlapping frames to the data
[sig,fs] = audioread(noisy_filename); %read the input file
FFT_POINTS = 1024;  %specify number of points of fft
LEN_WINDOW = 0.025; %frame length in seconds
OVERLAP_WINDOW = 0.0125; %overlap window step in seconds

frames = buffer(sig, LEN_WINDOW*fs,OVERLAP_WINDOW*fs); %use buffer command to separate signal into overlapping frames

frames = frames';

% h = tukeywin(length(frames),1); %Generate Tukey Window

h = hamming(length(frames)); %Generate Hamming Window

for n = 1:(LEN_WINDOW*fs)   %Apply Window to the frames
    frames(:,n) = frames(:,n).*(h);
    n = n+1;
end

%% Get noisy signal spectrum and estimte noise spectrum
cspec = fft(frames,FFT_POINTS,2); % complex spectrum of the noisy signal
pspec = abs(cspec).^2; % power spectrum of the noisy signal

phase = angle(cspec);  %phase of the noisy signal

noise_est = mean(pspec(:,1:5)); % noise_est is estimated from first five frames

%% Calculate value of subtraction parameter alpha
SNR = 20*log10(rms(sqrt(mean(pspec)))/rms(sqrt(noise_est))); % Get signal to noise ratio for calculation of alpha (subtraction parameter) 

if alpha_o == 3.0   %use alpha at 0 dB and SNR value to get alpha value
    alpha = subtraction_parameter_1(SNR,3);
else if alpha_o == 4.0
        alpha = subtraction_parameter(SNR,4);
    end
end

%% Here, We perform the modified spectral subtraction 

clean_spec = pspec.^(gamma) - repmat(alpha*(mean(noise_est.^(gamma))),size(pspec)); % subtract alpha times the noise estimate from noisy power spectrum
clean_spec = clean_spec.^(1/gamma); % We take into account exponent of power spectrum
clean_spec = clean_spec.*(Norm_G); % We apply normalization factor to improve level of processed signal 
clean_spec(clean_spec < beta.*mean(noise_est)) = beta*(mean(noise_est)); % spectral components are prevented from going below the spectral floor

%% Resynthesize signal (enhanced) from frames
reconstructed_frames = ifft(sqrt(clean_spec).*exp(phase),FFT_POINTS,2); % inverse fourier transform of processed signal is taken
reconstructed_frames = real(reconstructed_frames(:,1:LEN_WINDOW*fs)); % sometimes small complex residuals stay behind
enhanced_signal = deframe_sig(reconstructed_frames,[],LEN_WINDOW*fs,OVERLAP_WINDOW*fs,@hamming); %using the deframe function, we resynthesize signal from frames

%% Play the noisy signal and enhanced signal to see the effects of spectral subtraction,and then save the enhanced signal to a file
soundsc(sig,fs);             % listen to the original noisy signal
pause(5);                    % pause for 5 seconds 
soundsc(enhanced_signal',fs); % listen to the enhanced signal

audiowrite(enhanced_filename,enhanced_signal',fs); % the enhanced signal is written to a file with the specified filename 

function a=subtraction_parameter_1(SNR, alpha_o)
    %% function_1 to get alpha
    %This function will calculate values of alpha for a given SNR and
    %chosen alpha_o (alpha at 0dB).
    
    if SNR>=-5.0 && SNR<=20
        a = alpha_o - SNR*2/20;
        
    else if SNR<-5.0
            
            a=4;
        end
        if SNR>20
           
            a=1;
        
        end
        
    end
end
function a=subtraction_parameter(SNR, alpha_o)
    
    %% Function_2 to get alpha
    %This function will calculate values of alpha for a given SNR and
    %chosen alpha_o (alpha at 0dB).
    
    if SNR>=-5.0 && SNR<=20
        
        a = alpha_o - SNR*3/20;
    
    else if SNR<-5.0
            
            a=5;
        end
        
        if SNR>20
            
            a=1;
        end
        
    end
end

function rec_signal = deframe_sig(frames, signal_len, frame_len, frame_step, winfunc)
    % I have taken this function to deframe the signal from internet.
    % rec_signal = deframe_sig(frames, signal_len, frame_len, frame_step, wintype)
    % frames - a N by frame_len matrix of frames
    % signal_len - the length of the original unframed signal (if unknown, use [])
    % frame_len, frame_step - should be same as used by frame_sig (framing function)
    % winfunc - the same used when framing, this is undone before overlap-add
%% Function to deframe, taken from Internet
%Function deframe_sig taken from this source: https://raw.githubusercontent.com/jameslyons/spl_featgen/master/deframe_sig.m

num_frames = size(frames,1);
indices = repmat(1:frame_len, num_frames, 1) + ...
          repmat((0: frame_step: num_frames*frame_step-1)', 1, frame_len); 
padded_len = num_frames*frame_step + frame_len;
 
if isempty(signal_len)
    signal_len = padded_len;
end

rec_signal = zeros(1,padded_len);
window_correction = zeros(1,padded_len);
%wsyn = 0.5-0.5*cos((2*pi*((0:frame_len-1)+0.5))/frame_len);

win = winfunc(frame_len)';

for i = 1:num_frames
    window_correction(indices(i,:)) = window_correction(indices(i,:)) + win + eps;
    
    rec_signal(indices(i,:)) = rec_signal(indices(i,:)) + frames(i,:);
end

rec_signal = rec_signal./window_correction;
rec_signal = rec_signal(1:signal_len); % discard any padded samples

end
end