function f = midi2freq(m)
% f = midi2freq(m)
%     
% Convert MIDI note number (m=0-127) to 
% frequency, f,  in Hz
% (m can also be a vector or matrix)
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi

f = (440/32)*2.^((m-9)/12);
