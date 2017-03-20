﻿// Created by Sebastian Müller (smueller@ifi.uzh.ch) from the University of Zurich
// Created: 2017-03-15
// 
// Licensed under the MIT License.

using System;

namespace TaskDetectionTracker
{
    public class Settings
    {
        public const string TrackerName = "Task Detection Tracker";
        public const string DbTableTaskDetectionValidation = "user_validated_task_detection";

        #if Pilot_TaskDetection_March17
            public static bool IsEnabledByDefault = true;
        #else
            public static bool IsEnabledByDefault = false;
        #endif

        public static TimeSpan PopUpInterval = TimeSpan.FromMinutes(60);
        public static TimeSpan PopUpReminderInterval = TimeSpan.FromMinutes(5);

        public const int MinimumProcessTimeInSeconds = 10;
    }
}