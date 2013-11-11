function midi = readmidi(filename, rawbytes)
% midi = readmidi(filename, rawbytes)
% midi = readmidi(filename)
%
% Read MIDI file and store in a Matlab structure
% (use midiInfo.m to see structure detail)
%
% Inputs:
%  filename - input MIDI file
%  rawbytes - 0 or 1: Include raw bytes in structure
%             This info is redundant, but can be
%             useful for debugging. default=0
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi


if (nargin<2)
  rawbytes=0;
end

fid = fopen(filename);
[A count] = fread(fid,'uint8');
fclose(fid);

if (rawbytes) midi.rawbytes_all = A; end

% realtime events: status: [F8, FF].  no data bytes
%clock, undefined, start, continue, stop, undefined, active
%sensing, systerm reset

% file consists of "header chunk" and "track chunks"
%   4B  'MThd' (header) or 'MTrk' (track)
%   4B  32-bit unsigned int = number of bytes in chunk, not
%       counting these first 8


% HEADER CHUNK --------------------------------------------------------
% 4B 'Mthd'
% 4B length
% 2B file format
%    0=single track, 1=multitrack synchronous, 2=multitrack asynchronous
%    Synchronous formats start all tracks at the same time, while asynchronous formats can start and end any track at any time during the score.
% 2B track cout (must be 1 for format 0)
% 2B num delta-time ticks per quarter note
%

if ~isequal(A(1:4)',[77 84 104 100])  % double('MThd')
    error('File does not begin with header ID (MThd)');
end

header_len = decode_int(A(5:8));
if (header_len == 6)
else
    error('Header length != 6 bytes.');
end

format = decode_int(A(9:10));
if (format==0 || format==1 || format==2)
     midi.format = format;
else    
    error('Format does not equal 0,1,or 2');
end

num_tracks = decode_int(A(11:12));
if (format==0 && num_tracks~=1)
    error('File is format 0, but num_tracks != 1');
end

time_unit = decode_int(A(13:14));
if (bitand(time_unit,2^15)==0)
  midi.ticks_per_quarter_note = time_unit;
else
  error('Header: SMPTE time format found - not currently supported');
end

if (rawbytes)
  midi.rawbytes_header = A(1:14);
end

% end header parse ----------------------------------------------------






% BREAK INTO SEPARATE TRACKS ------------------------------------------
% midi.track(1).data = [byte byte byte ...];
% midi.track(2).date = ...
% ...
%
% Track Chunks---------
% 4B 'MTrk'
% 4B length (after first 8B)
%
ctr = 15;
for i=1:num_tracks
  
  if ~isequal(A(ctr:ctr+3)',[77 84 114 107])  % double('MTrk')
    error(['Track ' num2str(i) ' does not begin with track ID=MTrk']);
  end
  ctr = ctr+4;
  
  track_len = decode_int(A(ctr:ctr+3));
  ctr = ctr+4;
  
  % have track.rawbytes hold initial 8B also...
  track_rawbytes{i} = A((ctr-8):(ctr+track_len-1));
  
  if (rawbytes)
    midi.track(i).rawbytes_header = A(ctr-8:ctr-1);
  end
  
  ctr = ctr+track_len;
end
% ----------------------------------------------------------------------






% Events:
%  - meta events: start with 'FF'
%  - MIDI events: all others

% MIDI events:
%  optional command byte + 0,1,or 2 bytes of parameters
%  "running mode": command byte omitted.
%
% all midi command bytes have MSB=1
% all data for inside midi command have value <= 127 (ie MSB=0)
% -> so can determine running mode
% 
% meta events' data may have any values (meta events have to set
% len)
%



% 'Fn' MIDI commands:
%  no chan. control the entire system
%F8 Timing Clock
%FA start a sequence
%FB continue a sequence
%FC stop a sequence

% Meta events:
%  1B 0xFF
%  1B event type
%  1B length of additional data
%  ?? additional data
%


% "channel mode messages"
% have same code as "control change": 0xBn
%  but uses reserved controller numbers 120-127
%


%Midi events consist of an optional command byte 
% followed by zero, one or two bytes of parameters.
% In running mode, the command can be omitted, in 
% which case the last MIDI command specified is 
% assumed.  The first bit of a command byte is 1, 
% while the first bit of a parameter is always 0. 
%   In addition, the last 4 bits of a command 
%   indicate the channel to which the event should 
%   be sent; therefore, there are 6 possible 
%   commands (really 7, but we will discuss the x'Fn' 
%   commands later) that can be specified.  They are:


% parse tracks -----------------------------------------
for i=1:num_tracks
  
  track = track_rawbytes{i};

  if (rawbytes); midi.track(i).rawbytes = track; end
  
  msgCtr = 1;
  ctr=9;  % first 8B were MTrk and length
  while (ctr < length(track_rawbytes{i}))

    clear currMsg;
    currMsg.used_running_mode = 0;
    % note:
    %  .used_running_mode is necessary only to 
    %  be able to reconstruct a file _exactly_ from 
    %  the 'midi' structure.  this is helpful for 
    %  debugging since write(read(filename)) can be 
    %  tested for exact replication...
    %
    
    ctr_start_msg = ctr;
    
    [deltatime,ctr] = decode_var_length(track, ctr);
    
    % ?
    %if (rawbytes)
    %  currMsg.rawbytes_deltatime = track(ctr_start_msg:ctr-1);
    %end
    
    % deltaime must be 1-4 bytes long.
    % could check here...
    
    
    % CHECK FOR META EVENTS ------------------------
    % 'FF'
    if track(ctr)==255

      type = track(ctr+1);
      
      ctr = ctr+2;

      % get variable length 'length' field
      [len,ctr] = decode_var_length(track, ctr);

      % note: some meta events have pre-determined lengths...
      %  we could try verifiying they are correct here.

      thedata = track(ctr:ctr+len-1);
      chan = [];
      
      ctr = ctr + len;      

      midimeta = 0;
    
    else 
      midimeta = 1;
      % MIDI EVENT ---------------------------
      


      
      % check for running mode:
      if (track(ctr)<128)

	% make it re-do last command:
	%ctr = ctr - 1;
	%track(ctr) = last_byte;
	currMsg.used_running_mode = 1;
	
	B = last_byte;
	nB = track(ctr); % ?
	
      else
      
	B  = track(ctr);
	nB = track(ctr+1);

	ctr = ctr + 1;

      end
      
      % nibbles:
      %B  = track(ctr);
      %nB = track(ctr+1);

      
      Hn = bitshift(B,-4);
      Ln = bitand(B,15);

      chan = [];
      
      msg_type = midi_msg_type(B,nB);

      % DEBUG:
      if (i==2)
	  if (msgCtr==1)
	    disp(msg_type);
	  end
      end
      
      
      switch msg_type
      
       case 'channel_mode'
	
	% UNSURE: if all channel mode messages have 2 data byes (?)
	type = bitshift(Hn,4) + (nB-120+1);
	thedata = track(ctr:ctr+1);
	chan = Ln;
	
	ctr = ctr + 2;
	
	% ---- channel voice messages:
       case 'channel_voice'
	
	type = bitshift(Hn,4);
	len = channel_voice_msg_len(type); % var length data:
	thedata = track(ctr:ctr+len-1);
	chan = Ln;

	% DEBUG:
	if (i==2)
	  if (msgCtr==1)
	    disp([999  Hn type])
	  end
	end
	
	ctr = ctr + len;
	
       case 'sysex'
	
	% UNSURE: do sysex events (F0-F7) have 
	%  variable length 'length' field?
	
	[len,ctr] = decode_var_length(track, ctr);
	
	type = B;
	thedata = track(ctr:ctr+len-1);
	chan = [];
	
	ctr = ctr + len;
	
       case 'sys_realtime'
	
	% UNSURE: I think these are all just one byte
	type = B;
	thedata = [];
	chan = [];
	
      end
      
      last_byte = Ln + bitshift(Hn,4);
      
    end % end midi event 'if'

    
    currMsg.deltatime = deltatime;
    currMsg.midimeta = midimeta;
    currMsg.type = type;
    currMsg.data = thedata;
    currMsg.chan = chan;
    
    if (rawbytes)
      currMsg.rawbytes = track(ctr_start_msg:ctr-1);
    end
    
    midi.track(i).messages(msgCtr) = currMsg;
    msgCtr = msgCtr + 1;

    
  end % end loop over rawbytes
end % end loop over tracks

function val=decode_int(A)

val = 0;
for i=1:length(A)
  val = val + bitshift(A(length(A)-i+1), 8*(i-1));
end


function len=channel_voice_msg_len(type)

if     (type==128); len=2;
elseif (type==144); len=2;
elseif (type==160); len=2;
elseif (type==176); len=2;
elseif (type==192); len=1;
elseif (type==208); len=1;
elseif (type==224); len=2;
else
  disp(type); error('bad channel voice message type');
end


%
% decode variable length field (often deltatime)
%
%  return value and new position of pointer into 'bytes'
%
function [val,ptr] = decode_var_length(bytes, ptr)

keepgoing=1;
val = 0;
while (keepgoing)
  % check MSB:
  %  if MSB=1, then delta-time continues into next byte...
  if(~bitand(bytes(ptr),128))
    keepgoing=0;
  end
  % keep appending last 7 bits from each byte in the deltatime:
  val = val*128 + rem(bytes(ptr), 128);
  ptr=ptr+1;
end




%
% Read first 2 bytes of msg and 
%  determine the type
%  (most require only 1st byte)
%
% str is one of:
%  'channel_mode'
%  'channel_voice'
%  'sysex'
%  'sys_realtime'
%
function str=midi_msg_type(B,nB)

Hn = bitshift(B,-4);
Ln = bitand(B,7);

% ---- channel mode messages:
%if (Hn==11 && nB>=120 && nB<=127)
if (Hn==11 && nB>=122 && nB<=127)
  str = 'channel_mode';

  % ---- channel voice messages:
elseif (Hn>=8 && Hn<=14)
  str = 'channel_voice';
  
  %  ---- sysex events:
elseif (Hn==15 && Ln>=0 && Ln<=7)
  str = 'sysex';

  % system real-time messages
elseif (Hn==15 && Ln>=8 && Ln<=15)
  % UNSURE: how can you tell between 0xFF system real-time
  %   message and 0xFF meta event?
  %   (now, it will always be processed by meta)
  str = 'sys_realtime';
  
else
  % don't think it can get here...
  error('bad midi message');
end
