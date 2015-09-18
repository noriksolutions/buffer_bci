seqLen=testSeqLen;

%==========================================================================
% Initialize the display
%==========================================================================
%Set the frame size for the stimulus frame, make axes invisible, 
%remove menubar and toolbar. Also set the background color for the frame.
stimfig = figure(2);
clf;
set(stimfig,'Name','Experiment - Testing',...
    'color',framebgColor,'menubar','none','toolbar','none',...
    'renderer','painters','doublebuffer','on','Interruptible','off');
set(stimfig,'Units','pixel');wSize=get(stimfig,'position');set(stimfig,'units','normalized');% win size in pixels

ax=axes('position',[.1 .1 .8 .8],'visible','off','box','off','xtick',[], ...
        'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
        'color',[0 0 0],'DrawMode','fast','nextplot','replacechildren',...
        'xlim',axlim(:,1),'ylim',axlim(:,2),'ydir','reverse');
hold on;
    
%Create a text object with no text in it, center it, set font and color
txthdl = text(mean(axlim(:,1)),mean(axlim(:,2)), ' ',...
				  'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle',...
				  'fontunits','pixel','fontsize',.05*wSize(4),...
				  'color',[0.75 0.75 0.75],'visible','off');
 
%Create the white square image
whiteSquare = ones(1,1,3); %RGB 1 white pixel

% Create image object with right size/position to hold the stimuli
% to update the image contents Use: set(imghdl,'cdata',newData)
% N.B.: Matlab automatically re-scales new data when added to fix the size of the 
%       box used here.
imghdl= image(axlim(:,1),axlim(:,2),whiteSquare, 'visible', 'off');

%==========================================================================
% LOAD & SET-UP TARGET PICTURES + TARGET PIECES + DISTRACTOR PIECES 
%==========================================================================
%Load the full target pictures
targets=loadnSliceImages(tgtDir);
dists  =loadnSliceImages(distDir);
fprintf('All images loaded.\n');

%==========================================================================
% 5. CREATE ARRAYS FOR RANDOM PICTURE/PIECE SELECTIONS AND FLASH ORDERS
%==========================================================================
    
%Create  arrays for all sequences with random numbers to select each 
%distractor piece that should be flashed (= number of flashes - number of
%target pieces that is flashed)
distOrder = zeros(seqLen,nSeq); % order of distractor pictures
distPieces= zeros(seqLen,nSeq); % order of distractor pieces of the picture
for i = 1:size(distPieces,2);
   for j = 1:size(distPieces,1);
	  distOrder(j,i)   = randi(numel(dists)); % randomly pick picture to get piece from
	  % randomly pick piece of this picture
	  distPieces(j, i) = randi(numel(dists(distOrder(j,i)).pieces)); 
   end
end

%==========================================================================
% 6. START STIMULUS PRESENTATION AND THE ACTUAL DISPLAY OF THINGS
%==========================================================================

%Change text object and display start-up texts
set(txthdl,'string', 'Click mouse when ready', 'visible', 'on')
waitforbuttonpress;
set(txthdl,'visible', 'off');

%Send a start of training event
sendEvent('stimulus.testing', 'start');

%Start the sequences
for seqi = 1:nSeq
    [fn] = uigetfile(fullfile(fileparts(mfilename('fullpath')),strcat(tgtDir,'/*.jpg')),'Pick a Target');
    fn = fn(1:end-4);
    for tix = 1:size(targets,2)
        if (find(strcmp(targets(tix).name, fn)) == 1)
            tgtIdx = tix;
        end
    end
	 
	 tgtInfo= targets(tgtIdx);
	 % generate flash the ordering for this sequence, min-3, max-9 between flashes
	 flashOrder = zeros(seqLen,1);
	 si=1; while si<numel(flashOrder); flashOrder(si)=1; si=si+ceil((.5+rand(1))*tti); end; 
	 % generate a piece order for this sequence
	 tgtPiecesSeq= mkStimSeqRand(numel(tgtInfo.pieces),sum(flashOrder>0),1,3);
	 tgtPieces=[]; for ei=1:size(tgtPiecesSeq,2); tgtPieces(ei,1)=find(tgtPiecesSeq(:,ei)>0,1); end;

    %Send an event to indicate that a sequence has started
    sendEvent('stimulus.sequence', 'start');

    %Show target image
    set(imghdl,'cdata',tgtInfo.image,'visible','on');
    drawnow;
    sendEvent('stimulus.target.image',tgtInfo.name);
    sleepSec(targetDuration);
    
    set(imghdl, 'visible', 'off');
    drawnow;
	 if ( verb>0 ) fprintf('%d) tgt=%s',seqi,tgtInfo.name); end;
    sleepSec(postTargetDuration);
     
    piecesTaken = 0;
    distTaken = 0;
    %Flash pieces in the center of the screen
    seqStartTime=getwTime();
    % time in sec from seq start when stimulus should occur
    stimTime=(1:seqLen)*(stimDuration+whiteSquareDuration);
    for stimi = 1:seqLen
        %Flash the next piece
        %If the random order array says target take the next target piece
        if (flashOrder(stimi) == 1)
           piecesTaken= piecesTaken + 1;
			  flashVal   = 'target';
			  imgInfo    = tgtInfo;
           piece      = tgtPieces(piecesTaken);

        %If the random order array says distractor take the next distractor
        elseif (flashOrder(stimi) == 0)
          distTaken  = distTaken + 1;
			 distIdx    = distOrder(distTaken,seqi);
			 flashVal   = 'dist';
			 imgInfo    = dists(distIdx);
          piece      = distPieces(distTaken, seqi);
		  end

		  % show the choosen image
		  img    = imgInfo.pieces{piece};
		  set(imghdl,'cdata',imgInfo.pieces{piece}); % update the image
		  %% imghdl = image(linspace(0,1,size(img,2)),linspace(0,1,size(img,1)),...
		  %% 					  img, 'visible', 'off');
        set(imghdl, 'visible', 'on');
        % sleep until the draw time
        sleepSec(max(0,stimTime(stimi) - (getwTime()-seqStartTime)));
        drawnow;        
        %send events describing what just happened
        sendEvent('stimulus.target', flashVal);                       % target state
		  sendEvent('stimulus.image', sprintf('%s/%d',imgInfo.name,piece)); % image info
		  if ( verb>0 ) if flashOrder(stimi) fprintf('t'); else fprintf('.'); end; end;
        
        %Flash the white square
        set(imghdl,'cdata',whiteSquare,'visible','on');
        % sleep until the white-square time
        sleepSec(max(0,stimTime(stimi)+stimDuration - (getwTime()-seqStartTime)));
        drawnow;
        sendEvent('stimulus.blank', 1);
    end
    sleepSec(whiteSquareDuration);
	if ( verb>0 ) fprintf('\n'); end;

    %Cover last flashed piece up
    set(imghdl,'visible','off');
    drawnow;    
    %Send an event to indicate the sequence has ended
    sendEvent('stimulus.sequence', 'end');
    
    sleepSec(interSeqDuration);    
end

%Send an event to indicate that training has ended
sendEvent('stimulus.testing', 'end');

%Thank subject and end experiment
set(txthdl,'string', 'Thank you for participating!','visible', 'on');
drawnow;
sleepSec(textDuration);
