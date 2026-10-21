+++
date = '2026-10-14T01:43:33+03:00'
draft = false
title = 'A better way of listening to music? - My custom music player'

categories = ["Programming"]
tags = ["Music", "Kotlin"]
+++

I always thought it's a good idea to have a more structured approach when listening to music. When we listen to music we tend maybe to overplay for example an album or a playlist.

This is not really the most beneficial thing for us, as this is essentially about our pleasure of listening to the same thing that excites us. Playing the same tracks over and over again is predictable and doesn't bring much gain to you.

The idea of this 'debloated music player' is to force you to listen more rigurously to music by doing this:

- it scans your local music library, those are just album folders with tracks in them

- it keeps track of how many listens you have per album and it locks your album after you reach 2

At the end, you end up listening to each of the albums in the library twice. Once you clear your album list, move on to other music, other genres, new batch of albums and so on.

Why I chose 2 plays per album? Sometimes music might be hard to assimilate quickly, so a couple replays are necessary to be able to confidently say: "Yeah, I listened to that album"

This app is built in Kotlin, completely from 2-3 claude prompts. I haven't written a single line of code for this. From the moment I had the idea, in 20 mins I had the app on my phone.

The github repository for it is available here: https://github.com/petru-robu/check-beat

Feel free to built it for yourself if you've been searching for something like this as well. And also feel free to contribute to the app on github.

And if you are sad you need to have local audio files for this and you can't use streaming, you might want to take a look [here](https://www.rutracker.org).