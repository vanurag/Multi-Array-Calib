% this script generates the first set of results in the paper
% It calculates the transformation between the velodyne and camera 0 for drive
% 28 of the kitti data set using the presented method and a simple equal
% weighted least squares method

%% user set variables

%number of scans to use
scansTimeRange = 100;
%scansTimeRange = 5:5:100;

%number of scans to combine in metric refine step
numScans = 3;

%number of times to perform test
reps = 10;

%samples
timeSamples = 100000;

%% load sensor data
CalibPath(true);
%make sure to read in cameras last (due to issue with how I compensate for scale)
sensorData = LoadSensorData('Kitti','Cam1','Cam2');

%gives results in terms of positions rather then coordinate frames
%less usful more intuative
sensorData = InvertSensorData(sensorData);

%% fix timestamps
[sensorData, offsets] = CorrectTimestamps(sensorData, timeSamples);

%% run calibration
    
outT = cell(100,1);
outV = cell(100,1);

outTB = cell(100,1);
outVB = cell(100,1);

for w = 1:reps
    tic
    
    %get random contiguous scans to use
    sDataBase = RandTformTimes(sensorData, scansTimeRange);
    
    %evenly sample data
    sData = SampleData2(sDataBase);
    
    %remove uninformative data
    sData = RejectPoints(sData, 10, 0.0001);

    %find rotation
    fprintf('Finding Rotation\n');
    rotVec = RoughR(sData);
    rotVec = OptR(sData, rotVec);
    rotVarL = ErrorEstCR(sData, rotVec,0.01);
    rotVarU = ErrorEstR(sData, rotVec);
    
    fprintf('Rotation:\n');
    disp(rotVec);
    fprintf('Rotation sd:\n');
    disp(sqrt(rotVarL));
    
    %find camera transformation scale (only used for RoughT, OptT does its
    %own smarter/better thing
    fprintf('Finding Camera Scale\n');
    sDataS = EasyScale(sData, rotVec, rotVarL,zeros(2,3),ones(2,3));
    
    %show what we are dealing with
    PlotData(sDataS,rotVec);
    
    fprintf('Finding Translation\n');
    tranVec = RoughT(sDataS, rotVec);
    tranVec = OptT(sData, tranVec, rotVec, rotVarL);
    tranVarL = ErrorEstCT(sData, tranVec, rotVec, rotVarL, 0.01);
    tranVarU = ErrorEstT(sData, tranVec, rotVec, rotVarU);
    
    fprintf('Translation:\n');
    disp(tranVec);
    fprintf('Translation sd:\n');
    disp(sqrt(tranVarL));

    %get grid of transforms
    fprintf('Generating transformation grid\n');
    [TGrid, vTGrid] = GenTformGrid(tranVec, rotVec, tranVarL, rotVarL);
     
    %refine transforms using metrics
    fprintf('Refining transformations\n');
    [TGridR, vTGridR] = MetricRefine(TGrid, vTGrid, sDataBase, numScans);
     
    %correct for differences in grid
    fprintf('Combining results\n');
    [finalVec, finalVar] = OptGrid(TGridR, vTGridR);

end
