midi = readmidi('jesu.mid')

%----- converting MIDI to audio ----------

% (Fs = sample rate. here, uses default 44.1k.)
[y,Fs] = midi2audio(midi);    

%% listen in matlab:
soundsc(y, Fs);  % FM-synth

% a couple other very basic synth methods included:
y = midi2audio(midi, Fs, 'sine');
soundsc(y,Fs);

y = midi2audio(midi, Fs, 'saw');
soundsc(y,Fs);

% save to file:
% (normalize so as not clipped in writing to wav)
y = .95.*y./max(abs(y));
wavwrite(y, Fs, 'out.wav');

%----- analyze MIDI info ----------

%% just display info:
midiInfo(midi);

%% convert to 'Notes' matrix:
Notes = midiInfo(midi,0);

%% compute piano-roll:
[PR,t,nn] = piano_roll(Notes);

%% display piano-roll:
figure;
imagesc(t,nn,PR);
axis xy;
xlabel('time (sec)');
ylabel('note number');

%% also, can do piano-roll showing velocity:
[PR,t,nn] = piano_roll(Notes,1);

figure;
imagesc(t,nn,PR);
axis xy;
xlabel('time (sec)');
ylabel('note number');

%------------------------------------------------------------

% initialize matrix:
N = 13;  % num notes
M = zeros(N,6);

M(:,1) = 1;         % all in track 1
M(:,2) = 1;         % all in channel 1
M(:,3) = (60:72)';      % note numbers: one ocatave starting at middle C (60)
M(:,4) = round(linspace(80,120,N))';  % lets have volume ramp up 80->120
M(:,5) = (.5:.5:6.5)';  % note on:  notes start every .5 seconds
M(:,6) = M(:,5) + .5;   % note off: each note has duration .5 seconds

midi_new = matrix2midi(M);
writemidi(midi_new, 'testout.mid');

%------------------------------------------------------------

% initialize matrix:
N = 200;
M = zeros(N,6);

M(:,1) = 1;         % all in track 1
M(:,2) = 1;         % all in channel 1

M(:,3) = 30 + round(60*rand(N,1));  % random note numbers

M(:,4) = 60 + round(40*rand(N,1));  % random volumes

M(:,5) = 10 * rand(N,1);
%M(:,6) = M(:,5) + .2 + 2 * rand(N,1);
M(:,6) = M(:,5) + .2;

midi_new = matrix2midi(M);
writemidi(midi_new, 'testout2.mid');

