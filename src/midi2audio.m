function [y,Fs]=midi2audio(input,Fs,synthtype)
% y = midi2audio(input, Fs, synthtype)
% y = midi2audio(input, Fs)
% y = midi2audio(input)
%
% Convert midi structure to a digital waveform
%
% Inputs:
%  input - can be one of:
%    a structure: matlab midi structure (created by readmidi.m)
%    a string: a midi filename
%    other: a 'Notes' matrix (as ouput by midiInfo.m)
%
%  synthtype - string to choose synthesis method
%      passed to synth function in synth.m
%      current choices are: 'fm', 'sine' or 'saw'
%      default='fm'
%
%  Fs - sampling frequency in Hz (beware of aliasing!)
%       default =  44.1e3

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi

if (nargin<2)
  Fs=44.1e3;
end
if (nargin<3)
  synthtype='fm';
end

endtime = -1;
if (isstruct(input))
  [Notes,endtime] = midiInfo(input,0);
elseif (ischar(input))
  [Notes,endtime] = midiInfo(readmidi(input), 0);
else
  Notes = input;
end

% t2 = 6th col
if (endtime == -1)
  endtime = max(Notes(:,6));
end
if (length(endtime)>1)
  endtime = max(endtime);
end


y = zeros(1,ceil(endtime*Fs));

for i=1:size(Notes,1)

  f = midi2freq(Notes(i,3));
  dur = Notes(i,6) - Notes(i,5);
  amp = Notes(i,4)/127;

  yt = synth(f, dur, amp, Fs, synthtype);

  n1 = floor(Notes(i,5)*Fs)+1;
  N = length(yt);  

  n2 = n1 + N - 1;
  
  % hack: for some examples (6246525.midi), one yt
  %       extended past endtime (just by one sample in this case)
  % todo: check why that was the case.  For now, just truncate,
  if (n2 > length(y))
    ndiff = n2 - length(y);
    % 
    yt = yt(1:(end-ndiff));
    n2 = n2 - ndiff;
  end

  % ensure yt is [1,N]:
  y(n1:n2) = y(n1:n2) + reshape(yt,1,[]);

end
