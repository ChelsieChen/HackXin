clear all;
%CIFAR_DIR='/path/to/cifar/cifar-10-batches-mat/';
%Modified by Xinxi
CIFAR_DIR='';


assert(~strcmp(CIFAR_DIR, '/path/to/cifar/cifar-10-batches-mat/'), ...
       ['You need to modify kmeans_demo.m so that CIFAR_DIR points to ' ...
        'your cifar-10-batches-mat directory.  You can download this ' ...
        'data from:  http://www.cs.toronto.edu/~kriz/cifar-10-matlab.tar.gz']);

%% Configuration
addpath minFunc;
rfSize = 6;
numCentroids=1600;
whitening=true;
numPatches = 40000;
CIFAR_DIM=[32 32 3];

%% Load CIFAR training data
fprintf('Loading training data...\n');
%Modified by Xinxi
f1=load([CIFAR_DIR '/a4data.mat']);

%f1=load([CIFAR_DIR '/data_batch_1.mat']);
%f2=load([CIFAR_DIR '/data_batch_2.mat']);
%f3=load([CIFAR_DIR '/data_batch_3.mat']);
%f4=load([CIFAR_DIR '/data_batch_4.mat']);
%f5=load([CIFAR_DIR '/data_batch_5.mat']);

%trainX = double([f1.data; f2.data; f3.data; f4.data; f5.data]);
%trainY = double([f1.labels; f2.labels; f3.labels; f4.labels; f5.labels]) + 1; % add 1 to labels!
%Modified by Xinxi
trainX = double([f1.data_train;f1.data_nolabel]);
%trainX2 = double([f1.data_train]);
trainY = double([f1.labels_train]); % add 1 to labels!

%clear f1 f2 f3 f4 f5;
%Modified by Xinxi
clear f1;

% extract random patches
patches = zeros(numPatches, rfSize*rfSize*3);
for i=1:numPatches
  if (mod(i,10000) == 0) fprintf('Extracting patch: %d / %d\n', i, numPatches); end
  
  r = random('unid', CIFAR_DIM(1) - rfSize + 1);
  c = random('unid', CIFAR_DIM(2) - rfSize + 1);
  patch = reshape(trainX(mod(i-1,size(trainX,1))+1, :), CIFAR_DIM);
  patch = patch(r:r+rfSize-1,c:c+rfSize-1,:);
  patches(i,:) = patch(:)';
end

% normalize for contrast
patches = bsxfun(@rdivide, bsxfun(@minus, patches, mean(patches,2)), sqrt(var(patches,[],2)+10));

% whiten
if (whitening)
  C = cov(patches);
  M = mean(patches);
  [V,D] = eig(C);
  P = V * diag(sqrt(1./(diag(D) + 0.1))) * V';
  patches = bsxfun(@minus, patches, M) * P;
end

% run K-means
centroids = run_kmeans(patches, numCentroids, 20);
show_centroids(centroids, rfSize); drawnow;

% extract training features
if (whitening)
  trainXC = extract_features(trainX, centroids, rfSize, CIFAR_DIM, M,P);
else
  trainXC = extract_features(trainX, centroids, rfSize, CIFAR_DIM);
end

% standardize data
trainXC_mean = mean(trainXC);
trainXC_sd = sqrt(var(trainXC)+0.01);
trainXCs = bsxfun(@rdivide, bsxfun(@minus, trainXC, trainXC_mean), trainXC_sd);
trainXCs = [trainXCs, ones(size(trainXCs,1),1)];

% train classifier using SVM
C = 100;
theta = train_svm(trainXCs, trainY, C);

[val,labels] = max(trainXCs*theta, [], 2);
fprintf('Train accuracy %f%%\n', 100 * (1 - sum(labels ~= trainY) / length(trainY)));

%%%%% TESTING %%%%%

%% Load CIFAR test data
fprintf('Loading test data...\n');
%f1=load([CIFAR_DIR '/test_batch.mat']);

%Modified by Xinxi
f1=load([CIFAR_DIR '/a4data.mat']);

testX = double(f1.data);
testY = double(f1.labels);
clear f1;

% compute testing features and standardize
if (whitening)
  testXC = extract_features(testX, centroids, rfSize, CIFAR_DIM, M,P);
else
  testXC = extract_features(testX, centroids, rfSize, CIFAR_DIM);
end
testXCs = bsxfun(@rdivide, bsxfun(@minus, testXC, trainXC_mean), trainXC_sd);
testXCs = [testXCs, ones(size(testXCs,1),1)];

% test and print result
[val,labels] = max(testXCs*theta, [], 2);
%fprintf('Test accuracy %f%%\n', 100 * (1 - sum(labels ~= testY) / length(testY)));

