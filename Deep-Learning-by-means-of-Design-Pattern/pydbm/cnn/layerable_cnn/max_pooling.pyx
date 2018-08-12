# -*- coding: utf-8 -*-
from logging import getLogger
from pydbm.cnn.layerable_cnn import LayerableCNN
from pydbm.synapse import Synapse
import numpy as np
cimport numpy as np
ctypedef np.float64_t DOUBLE_t


class MaxPooling(LayerableCNN):
    '''
    Max Pooling operator.
    '''

    def __init__(
        self,
        graph,
        int pool_height,
        int pool_width,
        int stride=1,
        int pad=0
    ):
        '''
        Init.
        
        Args:
            graph:          is-a `Synapse`.
            pool_heigh:     Height of pool.
            pool_width:     Width of pool.
            stride:         Stride.
            pad:            Padding.

        '''
        if isinstance(graph, Synapse):
            self.__graph = graph
        else:
            raise TypeError()

        self.__pool_height = pool_height
        self.__pool_width = pool_width
        self.__stride = stride
        self.__pad = pad

    def forward_propagate(self, np.ndarray[DOUBLE_t, ndim=4] img_arr):
        '''
        Forward propagation in CNN layers.
        
        Override.

        Args:
            matriimg_arr:      4-rank array like or sparse matrix.
        
        Returns:
            4-rank array like or sparse matrix.
        '''
        cdef int img_sample_n = img_arr.shape[0]
        cdef int img_channel = img_arr.shape[1]
        cdef int img_height = img_arr.shape[2]
        cdef int img_width = img_arr.shape[3]

        cdef int result_height = int(1 + (img_height - self.__pool_height) / self.__stride)
        cdef int result_width = int(1 + (img_width - self.__pool_width) / self.__stride)

        cdef np.ndarray[DOUBLE_t, ndim=2] reshaped_img_arr = self.affine_transform(
            img_arr,
            self.__pool_height, 
            self.__pool_width, 
            self.__stride, 
            self.__pad
        )
        reshaped_img_arr = reshaped_img_arr.reshape(-1, self.__pool_height * self.__pool_width)
        cdef np.ndarray[DOUBLE_t, ndim=2] max_index_arr = reshaped_img_arr.argmax(axis=1)
        cdef np.ndarray[DOUBLE_t, ndim=2] result_arr = np.max(reshaped_img_arr, axis=1)
        cdef np.ndarray[DOUBLE_t, ndim=4] _result_arr = result_arr.reshape(
            img_sample_n,
            result_height,
            result_width,
            img_channel
        )
        _result_arr = _result_arr.transpose(0, 3, 1, 2)

        self.__img_arr = img_arr
        self.__max_index_arr = max_index_arr

        return _result_arr

    def back_propagate(self, np.ndarray[DOUBLE_t, ndim=4] delta_arr):
        '''
        Back propagation in CNN layers.
        
        Override.

        Args:
            delta_arr:      4-rank array like or sparse matrix.
        
        Returns:
            3-rank array like or sparse matrix.
        '''
        cdef np.ndarray[DOUBLE_t, ndim=4] _delta_arr = delta_arr.transpose(0, 2, 3, 1)
        
        cdef int pool_shape = self.__pool_height * self.__pool_width
        cdef np.ndarray[DOUBLE_t, ndim=2] delta_pool_arr = np.zeros((_delta_arr.size, pool_shape))
        cdef np.ndarray[DOUBLE_t, ndim=1] flatten_arr = self.__max_index_arr.flatten()
        delta_pool_arr[np.arange(self.__max_index_arr.size), flatten_arr] = _delta_arr.flatten()
        cdef int delta_row = _delta_arr.shape[0]
        cdef int delta_col = _delta_arr.shape[1]
        delta_pool_arr = delta_pool_arr.reshape((delta_row, delta_col) + (pool_shape, ))

        delta_reshaped_pool_arr = delta_pool_arr.reshape(
            delta_pool_arr.shape[0] * delta_pool_arr.shape[1] * delta_pool_arr.shape[2], 
            -1
        )
        cdef np.ndarray[DOUBLE_t, ndim=4] delta_img_arr = self.affine_to_img(
            delta_reshaped_pool_arr,
            self.__img_arr,
            self.__pool_height,
            self.__pool_width,
            self.__stride,
            self.__pad
        )
        
        return delta_img_arr
