function rawbytes=writemidi(midi,filename,do_run_mode)
% rawbytes=writemidi(midi,filename,do_run_mode)
%
% writes to a midi file
%
% midi is a structure like that created by readmidi.m
%
% do_run_mode: flag - use running mode when possible.
%    if given, will override the msg.used_running_mode
%    default==0.  (1 may not work...)
%
% TODO: use note-on for note-off... (for other function...)
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi


%if (nargin<3)
do_run_mode = 0;
%end


% do each track:
Ntracks = length(midi.track);

for i=1:Ntracks

  databytes_track{i} = [];
  
  for j=1:length(midi.track(i).messages)

    msg = midi.track(i).messages(j);

    msg_bytes = encode_var_length(msg.deltatime);

    if (msg.midimeta==1)

      % check for doing running mode
      run_mode = 0;
      run_mode = msg.used_running_mode;
      
      % should check that prev msg has same type to allow run
      % mode...
      
      
      %      if (j>1 && do_run_mode && msg.type == midi.track(i).messages(j-1).type)
%	run_mode = 1;
%      end


msg_bytes = [msg_bytes; encode_midi_msg(msg, run_mode)];
    
    
    else
      
      msg_bytes = [msg_bytes; encode_meta_msg(msg)];
      
    end

%    disp(msg_bytes')

%if (msg_bytes ~= msg.rawbytes)
%  error('rawbytes mismatch');
%end

    databytes_track{i} = [databytes_track{i}; msg_bytes];
    
  end
end 


% HEADER
% double('MThd') = [77 84 104 100]
rawbytes = [77 84 104 100 ...
	    0 0 0 6 ...
	    encode_int(midi.format,2) ...
	    encode_int(Ntracks,2) ...
	    encode_int(midi.ticks_per_quarter_note,2) ...
	   ]';

% TRACK_CHUCKS
for i=1:Ntracks
  a = length(databytes_track{i});
  % double('MTrk') = [77 84 114 107]
  tmp = [77 84 114 107 ...
	 encode_int(length(databytes_track{i}),4) ...
	 databytes_track{i}']';
  rawbytes(end+1:end+length(tmp)) = tmp;
end


% write to file
fid = fopen(filename,'w');
%fwrite(fid,rawbytes,'char');
fwrite(fid,rawbytes,'uint8');
fclose(fid);

% return a _column_ vector
function A=encode_int(val,Nbytes)

for i=1:Nbytes
  A(i) = bitand(bitshift(val, -8*(Nbytes-i)), 255);
end


function bytes=encode_var_length(val)

% What should be done for fractional deltatime values?
% Need to do this round() before anything else, including
%  that first check for val<128 (or results in bug for some fractional values).
% Probably should do rounding elsewhere and require
% this function to take an integer.
val = round(val)

if val<128 % covers 99% cases!
    bytes = val;
    return
end
binStr = dec2base(round(val),2);
Nbytes = ceil(length(binStr)/7);
binStr = ['00000000' binStr];
bytes = [];
for i=1:Nbytes
  if (i==1)
    lastbit = '0';
  else
    lastbit = '1';
  end
  B = bin2dec([lastbit binStr(end-i*7+1:end-(i-1)*7)]);
  bytes = [B; bytes];
end


function bytes=encode_midi_msg(msg, run_mode)

bytes = [];

if (run_mode ~= 1)
  bytes = msg.type;
  % channel:
  bytes = bytes + msg.chan;  % lower nibble should be chan
end

bytes = [bytes; msg.data];

function bytes=encode_meta_msg(msg)

bytes = 255;
bytes = [bytes; msg.type];
bytes = [bytes; encode_var_length(length(msg.data))];
bytes = [bytes; msg.data];

