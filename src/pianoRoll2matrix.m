function notes = pianoRoll2matrix(roll, dt, nn)
% notes = pianoRoll2matrix(roll, dt, nn)
% Converts piano roll into a matrix of notes.
%
% Inputs:
%   roll:   Piano roll. e.g. could be generated with piano_roll.m
%   dt:     delta time - duration of ine step in seconds
%   nn:     note number at note index ti (map of pitches)
% 
% Outputs:
%   notes:  matrix of notes, that you could pass into matrix2midi()
%        1     2    3     4   5  6  
%       [track chan pitch vel t1 t2]

% Commited by: mikhail-matrosov

N = size(roll, 2);
notes = zeros(0, 6);

dn = min(nn)-1;
nN = numel(nn);

roll = [roll,zeros(nN,1)];
N=N+1;
noteCnt = 1;

for nn=1:nN
    vel = roll(nn, 1);
    dur = 1;
    for i=1:N
        velNew = roll(nn, i);
        if velNew == vel
            dur = dur+1;
        else
            if vel ~= 0
                notes(noteCnt,:) = [1, 0, nn+dn, vel, dt*(i-dur), dt*i];
                noteCnt = noteCnt+1;
            end
            dur = 1;
            vel = velNew;
        end
    end
end

notes = sortrows(notes, 5); % sort by start time

end

