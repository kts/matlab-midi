function [Notes,endtime] = midiInfo(midi,outputFormat,tracklist,verbose)
% [Notes,endtime] = midiInfo(midi,outputFormat,tracklist)
%
% Takes a midi structre and generates info on notes and messages
% Can return a matrix of note parameters and/or output/display 
%   formatted table of messages
%
% Inputs:
%  midi - Matlab structure (created by readmidi.m)
%  tracklist - which tracks to show ([] for all)
%  outputFormat
%   - if it's a string write the formated output to the file
%   - if 0, don't display or write formatted output
%   - if 1, just display (default)
% 
% outputs:
%   Notes - a matrix containing a list of notes, ordered by start time
%     column values are:
%      1     2    3  4   5  6  7       8
%     [track chan nn vel t1 t2 msgNum1 msgNum2]
%   endtime - time of end of track message
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi
if nargin<4
  verbose = 0;
end
if nargin<3
  tracklist=[];
  if nargin<2
    outputFormat=1;
  end
end
if (isempty(tracklist))
  tracklist = 1:length(midi.track);
end

current_tempo = 500000;  % default tempo


[tempos, tempos_time] = getTempoChanges(midi);

% What to do if no tempos are given?
%  This seems at leat get things to work (see eire01.mid)
if length(tempos) == 0
  tempos = [current_tempo];
  tempos_time = [0];
end


fid = -1;
if (ischar(outputFormat))
  fid = fopen(outputFormat,'w');
end

endtime = -1;

% each row:
%  1     2    3  4   5  6  7       8
% [track chan nn vel t1 t2 msgNum1 msgNum2]
Notes = zeros(0,8);

for i=1:length(tracklist)
  tracknum = tracklist(i);
    
  cumtime=0;
  seconds=0;

  Msg = cell(0);
  Msg{1,1} = 'chan';
  Msg{1,2} = 'deltatime';
  Msg{1,3} = 'time';
  Msg{1,4} = 'name';
  Msg{1,5} = 'data';
  
  for msgNum=1:length(midi.track(tracknum).messages)

    currMsg = midi.track(tracknum).messages(msgNum);
    
    midimeta  = currMsg.midimeta;
    deltatime = currMsg.deltatime;
    data      = currMsg.data;
    type      = currMsg.type;
    chan      = currMsg.chan;

    cumtime = cumtime + deltatime;
    seconds = seconds + deltatime*1e-6*current_tempo/midi.ticks_per_quarter_note;
    
    [mx ind] = max(find(cumtime >= tempos_time));
    if numel(ind)>0 % if only we found smth
        current_tempo = tempos(ind);
    else
        if verbose
            disp('No tempos_time found?');
        end
    end

    % find start/stop of notes:
    %    if (strcmp(name,'Note on') && (data(2)>0))
    % note on with vel>0:
    if (midimeta==1 && type==144 && data(2)>0)
      % note on:
       Notes(end+1,:) = [tracknum chan data(1) data(2) seconds 0 msgNum -1];
       %    elseif ((strcmp(name,'Note on') && (data(2)==0)) || strcmp(name,'Note off'))
       % note on with vel==0 or note off:
    elseif (midimeta==1 && ( (type==144 && data(2)==0) || type==128 ))
      
      % note off:
      %      % find index, wther tr,chan,and nn match, and not complete
      
      ind = find((...
	  (Notes(:,1)==tracknum) + ...
	  (Notes(:,2)==chan) + ...
	  (Notes(:,3)==data(1)) + ...
	  (Notes(:,8)==-1)...
	  )==4);
      
      if (length(ind)==0)
	%% was an error before; change to warning and ignore the message.
    if verbose
	  warning('ending non-open note?');
    end

      else
	if (length(ind)>1)
	  %% ??? not sure about this...
	  %disp('warning: found mulitple matches in endNote, taking first...');
	  %% should we take first or last? should we give a warning?
	  ind = ind(1);
	end
	
	% set info on ending:
	Notes(ind,6) = seconds;
	Notes(ind,8) = msgNum;
	
      end
	
	
      % end of track:
    elseif (midimeta==0 && type==47)
      if (endtime == -1)
	endtime = seconds;
      else
          if verbose
            disp('two "end of track" messages?');
          end
	endtime(end+1) = seconds;
      end
    
    
    end
    
    % we could check to make sure it ends with
    %  'end of track'

    
    if (outputFormat ~= 0)
      % get some specific descriptions:
      name = num2str(type);
      dataStr = num2str(data);

      if (isempty(chan))
	Msg{msgNum,1} = '-';
      else
	Msg{msgNum,1} = num2str(chan);
      end
      
      Msg{msgNum,2} = num2str(deltatime);
      Msg{msgNum,3} = formatTime(seconds);
      
      if (midimeta==0)
	Msg{msgNum,4} = 'meta';
      else
	Msg{msgNum,4} = '';
      end
      
      [name,dataStr] = getMsgInfo(midimeta, type, data);
      Msg{msgNum,5} = name;
      Msg{msgNum,6} = dataStr;
    end
    
  end %% end track.
  
  %% any note-on that are not turned off?
  nleft = sum(Notes(:,8)==-1);
  if (nleft > 0)
    %warning(sprintf('%d notes needed to be turned off at end of track.', nleft));
    Notes(Notes(:,8) == -1, 6) = seconds;
  end
  
  if (outputFormat ~= 0)
    printTrackInfo(Msg,tracknum,fid);
  end
  
end

% make this an option!!!
% - I'm not sure why it's needed...
% remove start silence:
first_t = min(Notes(:,5));
Notes(:,5) = Notes(:,5) - first_t;
Notes(:,6) = Notes(:,6) - first_t;

% sort Notes by start time:
[junk,ord] = sort(Notes(:,5));
Notes = Notes(ord,:);


if (fid ~= -1)
  fclose(fid);
end











function printTrackInfo(Msg,tracknum,fid)


% make cols same length instead of just using \t
for i=1:size(Msg,2)
  maxLen(i)=0;
  for j=1:size(Msg,1)
    if (length(Msg{j,i})>maxLen(i))
      maxLen(i) = length(Msg{j,i});
    end
  end
end


s='';
s=[s sprintf('--------------------------------------------------\n')];
s=[s sprintf('Track %d\n',tracknum)];
s=[s sprintf('--------------------------------------------------\n')];

if (fid == -1)
  disp(s)
else
  fprintf(fid,'%s',s);
end


for i=1:size(Msg,1)
  line='';
  for j=1:size(Msg,2)
    sp = repmat(' ',1,5+maxLen(j)-length(Msg{i,j}));
    m = Msg{i,j};
    m = m(:)';  % ensure column vector
%    line = [line Msg{i,j} sp];
    line = [line m sp];
  end
  
  if (fid == -1)
    disp(line)
  else
    fprintf(fid,'%s\n',line);
  end

end



function s=formatTime(seconds)

minutes = floor(seconds/60);
secs = seconds - 60*minutes;

s = sprintf('%d:%2.3f',minutes,secs);



function [name,dataStr]=getMsgInfo(midimeta, type, data);

% meta events:
if (midimeta==0)
  if     (type==0);  name = 'Sequence Number';            len=2;  dataStr = num2str(data);
  elseif (type==1);  name = 'Text Events';                len=-1; dataStr = char(data);
  elseif (type==2);  name = 'Copyright Notice';           len=-1; dataStr = char(data);
  elseif (type==3);  name = 'Sequence/Track Name';        len=-1; dataStr = char(data);
  elseif (type==4);  name = 'Instrument Name';            len=-1; dataStr = char(data);
  elseif (type==5);  name = 'Lyric';                      len=-1; dataStr = char(data);
  elseif (type==6);  name = 'Marker';                     len=-1; dataStr = char(data);
  elseif (type==7);  name = 'Cue Point';                  len=-1; dataStr = char(data);
  elseif (type==32); name = 'MIDI Channel Prefix';        len=1;  dataStr = num2str(data);
  elseif (type==47); name = 'End of Track';               len=0;  dataStr = '';
  elseif (type==81); name = 'Set Tempo';                  len=3;   
    val = data(1)*16^4+data(2)*16^2+data(3); dataStr = ['microsec per quarter note: ' num2str(val)];
  elseif (type==84); name = 'SMPTE Offset';               len=5;   
    dataStr = ['[hh;mm;ss;fr;ff]=' mat2str(data)];
  elseif (type==88); name = 'Time Signature';             len=4;   
    dataStr = [num2str(data(1)) '/' num2str(data(2)) ', clock ticks and notated 32nd notes=' num2str(data(3)) '/' num2str(data(4))];
  elseif (type==89); name = 'Key Signature';              len=2;   
    % num sharps/flats (flats negative)
    % but data(1) is unsigned 8-bit
    if (data(1)<=7)
       %   0   1   2    3    4   5     6     7   
      ss={'C','G','D', 'A', 'E','B',  'F#', 'C#'};
      dataStr = ss{data(1)+1};
    elseif (data(1)>=249)
       %    1   2    3    4   5     6    7   
       %   255   ...                    249
       ss={'F','Bb','Eb','Ab','Db','Gb','Cb'};
       dataStr = ss{255-data(1)+1};
    else
       dataStr = '?';
    end
    if (data(2)==0)
      dataStr = [dataStr ' Major'];
    else
      dataStr = [dataStr ' Minor'];
    end
    
  elseif (type==89); name = 'Sequencer-Specific Meta-event';   len=-1;  
    dataStr = char(data);
    % !! last two conflict...
  
  else
    name = ['UNKNOWN META EVENT: ' num2str(type)]; dataStr = num2str(data);
  end
  
% meta 0x21 = MIDI port number, length 1 (? perhaps)
else

  % channel voice messages:  
  %  (from event byte with chan removed, eg 0x8n -> 0x80 = 128 for
  %  note off)
  if     (type==128);  name = 'Note off';                 len=2; dataStr = ['nn=' num2str(data(1)) '  vel=' num2str(data(2))];
  elseif (type==144);  name = 'Note on';                  len=2; dataStr = ['nn=' num2str(data(1)) '  vel=' num2str(data(2))];
  elseif (type==160); name = 'Polyphonic Key Pressure';   len=2; dataStr = ['nn=' num2str(data(1)) '  vel=' num2str(data(2))];
  elseif (type==176); name = 'Controller Change';         len=2; dataStr = ['ctrl=' controllers(data(1)) '  value=' num2str(data(2))];
  elseif (type==192); name = 'Program Change';            len=1; dataStr = ['instr=' num2str(data)];
  elseif (type==208); name = 'Channel Key Pressure';      len=1; dataStr = ['vel=' num2str(data)];
  elseif (type==224); name = 'Pitch Bend';                len=2; 
    val = data(1)+data(2)*256;
    val = base2dec('2000',16) - val;
    dataStr = ['change=' num2str(val) '?'];
  
  % channel mode messages:
  %  ... unsure about data for these... (do some have a data byte and
  %  others not?)
  %
  % 0xC1 .. 0xC8
  elseif (type==193);  name = 'All Sounds Off';            dataStr = num2str(data);
  elseif (type==194);  name = 'Reset All Controllers';     dataStr = num2str(data);
  elseif (type==195); name = 'Local Control';             dataStr = num2str(data);
  elseif (type==196); name = 'All Notes Off';             dataStr = num2str(data);
  elseif (type==197); name = 'Omni Mode Off';             dataStr = num2str(data);
  elseif (type==198); name = 'Omni Mode On';              dataStr = num2str(data);
  elseif (type==199); name = 'Mono Mode On';              dataStr = num2str(data);
  elseif (type==200); name = 'Poly Mode On';              dataStr = num2str(data);
  
    % sysex, F0->F7
  elseif (type==240); name = 'Sysex 0xF0';              dataStr = num2str(data);
  elseif (type==241); name = 'Sysex 0xF1';              dataStr = num2str(data);
  elseif (type==242); name = 'Sysex 0xF2';              dataStr = num2str(data);
  elseif (type==243); name = 'Sysex 0xF3';              dataStr = num2str(data);
  elseif (type==244); name = 'Sysex 0xF4';              dataStr = num2str(data);
  elseif (type==245); name = 'Sysex 0xF5';              dataStr = num2str(data);
  elseif (type==246); name = 'Sysex 0xF6';              dataStr = num2str(data);
  elseif (type==247); name = 'Sysex 0xF7';              dataStr = num2str(data);
    
    % realtime
    % (i think have no data..?)
  elseif (type==248); name = 'Real-time 0xF8 - Timing clock';              dataStr = num2str(data);
  elseif (type==249); name = 'Real-time 0xF9';              dataStr = num2str(data);
  elseif (type==250); name = 'Real-time 0xFA - Start a sequence';              dataStr = num2str(data);
  elseif (type==251); name = 'Real-time 0xFB - Continue a sequence';              dataStr = num2str(data);
  elseif (type==252); name = 'Real-time 0xFC - Stop a sequence';              dataStr = num2str(data);
  elseif (type==253); name = 'Real-time 0xFD';              dataStr = num2str(data);
  elseif (type==254); name = 'Real-time 0xFE';              dataStr = num2str(data);
  elseif (type==255); name = 'Real-time 0xFF';              dataStr = num2str(data);
  

  else
    name = ['UNKNOWN MIDI EVENT: ' num2str(type)]; dataStr = num2str(data);
  end


end

function s=controllers(n)
if (n==1); s='Mod Wheel';
elseif (n==2); s='Breath Controllery';
elseif (n==4); s='Foot Controller';
elseif (n==5); s='Portamento Time';
elseif (n==6); s='Data Entry MSB';
elseif (n==7); s='Volume';
elseif (n==8); s='Balance';
elseif (n==10); s='Pan';
elseif (n==11); s='Expression Controller';
elseif (n==16); s='General Purpose 1';
elseif (n==17); s='General Purpose 2';
elseif (n==18); s='General Purpose 3';
elseif (n==19); s='General Purpose 4';
elseif (n==64); s='Sustain';
elseif (n==65); s='Portamento';
elseif (n==66); s='Sustenuto';
elseif (n==67); s='Soft Pedal';
elseif (n==69); s='Hold 2';
elseif (n==80); s='General Purpose 5';
elseif (n==81); s='Temp Change (General Purpose 6)';
elseif (n==82); s='General Purpose 7';
elseif (n==83); s='General Purpose 8';
elseif (n==91); s='Ext Effects Depth';
elseif (n==92); s='Tremelo Depthy';
elseif (n==93); s='Chorus Depth';
elseif (n==94); s='Detune Depth (Celeste Depth)';
elseif (n==95); s='Phaser Depth';
elseif (n==96); s='Data Increment (Data Entry +1)';
elseif (n==97); s='Data Decrement (Data Entry -1)';
elseif (n==98); s='Non-Registered Param LSB';
elseif (n==99); s='Non-Registered Param MSB';
elseif (n==100); s='Registered Param LSB';
elseif (n==101); s='Registered Param MSB';
else
  s='UNKNOWN CONTROLLER';
end

%Channel mode message values
%Reset All Controllers 	79 	121 	Val ??
%Local Control 	7A 	122 	Val 0 = off, 7F (127) = on
%All Notes Off 	7B 	123 	Val must be 0
%Omni Mode Off 	7C 	124 	Val must be 0
%Omni Mode On 	7D 	125 	Val must be 0
%Mono Mode On 	7E 	126 	Val = # of channels, or 0 if # channels equals # voices in receiver
%Poly Mode On 	7F 	127 	Val must be 0
