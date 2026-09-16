import sqlite3
import os
import re
import httpx
from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from schemas import (
    StoryDTO,
    ChapterDTO,
    GenreDTO,
    WriterDTO,
    UpdateFeedDTO,
    CreateStoryRequest,
    ShelfSyncItemDTO,
    ShelfSyncPayload,
    ShelfSyncResponse,
    HealthResponse
)

DB_PATH = os.environ.get("FABLE_DB_PATH", "fable.sqlite3")

app = FastAPI(
    title="Fable Cloud Synchronization & Literature Ingestion API",
    description="Asynchronous REST pipeline with live Gutenberg/Open Library ingestion, chapter parsing, and Last-Write-Wins (LWW) shelf sync.",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def extract_chapters_from_text(raw_text: str) -> list[dict]:
    """
    Parses raw full-length text from Project Gutenberg or external literary sites,
    stripping boilerplate licenses and splitting on structural chapter boundaries.
    """
    start_match = re.search(r'\*\*\*\s*START OF (THE|THIS) PROJECT GUTENBERG EBOOK[^\*]*\*\*\*', raw_text, re.IGNORECASE)
    end_match = re.search(r'\*\*\*\s*END OF (THE|THIS) PROJECT GUTENBERG EBOOK', raw_text, re.IGNORECASE)

    start_pos = start_match.end() if start_match else 0
    end_pos = end_match.start() if end_match else len(raw_text)
    clean_text = raw_text[start_pos:end_pos].strip()

    # Match standard Chapter markers
    pattern = r'(?:\r?\n){2,}(CHAPTER\s+[0-9IVXLCDM]+[^\r\n]*|Chapter\s+[0-9IVXLCDM]+[^\r\n]*|ACT\s+[0-9IVXLCDM]+[^\r\n]*|BOOK\s+[0-9IVXLCDM]+[^\r\n]*)'
    splits = re.split(pattern, clean_text)

    extracted: list[dict] = []
    if len(splits) > 2:
        chapter_idx = 1
        for i in range(1, len(splits), 2):
            ch_title = splits[i].strip()
            ch_body = splits[i+1].strip() if i+1 < len(splits) else ""
            # Filter out table of contents listings (which contain rapid chapter repetitions or are empty)
            if len(ch_body.strip()) >= 50 and ch_body.count("CHAPTER ") < 3 and ch_body.count("Chapter ") < 3:
                words = len(ch_body.split())
                extracted.append({
                    "chapter_number": chapter_idx,
                    "title": ch_title,
                    "content": ch_body,
                    "word_count": words
                })
                chapter_idx += 1

    # Fallback to Roman numeral markers (\n\nI\n\n, \n\nII\n\n)
    if not extracted:
        roman_pattern = r'(?:\r?\n){2,}([IVXLCDM]+)\s*(?:\r?\n){2,}'
        roman_splits = re.split(roman_pattern, clean_text)
        if len(roman_splits) > 2:
            chapter_idx = 1
            for i in range(1, len(roman_splits), 2):
                ch_title = f"Chapter {roman_splits[i].strip()}"
                ch_body = roman_splits[i+1].strip() if i+1 < len(roman_splits) else ""
                if len(ch_body.strip()) >= 50:
                    words = len(ch_body.split())
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": ch_body,
                        "word_count": words
                    })
                    chapter_idx += 1

    # Single-chapter tale fallback
    if not extracted:
        words = len(clean_text.split())
        extracted.append({
            "chapter_number": 1,
            "title": "Chapter I: The Complete Tale",
            "content": clean_text,
            "word_count": words
        })

    return extracted

def init_db():
    conn = get_db()
    with conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS stories (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                genre TEXT NOT NULL,
                chapter TEXT NOT NULL,
                synopsis TEXT NOT NULL,
                content TEXT NOT NULL,
                read_time_minutes INTEGER NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL,
                cover_image_name TEXT,
                hero_image_name TEXT,
                cover_image_url TEXT,
                total_pages INTEGER DEFAULT 5,
                current_page INTEGER DEFAULT 1,
                progress_percent INTEGER DEFAULT 0,
                rating REAL DEFAULT 4.9,
                saves_count TEXT DEFAULT '1.2k',
                reads_count TEXT DEFAULT '1.2k',
                is_tale_of_the_day INTEGER DEFAULT 0,
                is_recent_submission INTEGER DEFAULT 0,
                is_curator_spotlight INTEGER DEFAULT 0,
                badge_text TEXT,
                total_chapters INTEGER DEFAULT 1
            );
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS chapters (
                id TEXT PRIMARY KEY,
                story_id TEXT NOT NULL,
                chapter_number INTEGER NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                word_count INTEGER NOT NULL,
                created_at_utc TEXT NOT NULL,
                FOREIGN KEY(story_id) REFERENCES stories(id) ON DELETE CASCADE
            );
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS shelf_items (
                story_id TEXT PRIMARY KEY,
                reading_progress REAL NOT NULL,
                is_bookmarked INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                updated_at_utc TEXT NOT NULL
            );
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_chapters_story_id ON chapters (story_id);")

        cursor = conn.execute("SELECT COUNT(*) as count FROM stories")
        if cursor.fetchone()["count"] == 0:
            now_iso = datetime.now(timezone.utc).isoformat()
            
            # Seed authentic literary suite with full chapter extractions
            seed_catalog = [
                {
                    "id": "66666666-6666-6666-6666-666666666666",
                    "title": "Dracula",
                    "author": "Bram Stoker",
                    "genre": "Gothic",
                    "chapter": "Chapter I",
                    "synopsis": "Jonathan Harker journeys to the Carpathian mountains to seal a real estate transaction with Count Dracula, only to discover horrifying secrets within Castle Dracula.",
                    "content": "Before the sun had set, we reached the Bistritz pass. The grey of the evening had begun to fall, and the shadows of the mountains seemed to close in around us with every mile. The horses began to strain against the harness as the road turned sharply upward into the deep pine forests of Transylvania.",
                    "read_time_minutes": 7,
                    "cover_image_name": "cover_dracula",
                    "hero_image_name": "hero_dracula",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/345/pg345.cover.medium.jpg",
                    "is_tale_of_the_day": 1,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": "FEATURED MASTERPIECE",
                    "chapters": [
                        {
                            "number": 1,
                            "title": "CHAPTER I: Jonathan Harker's Journal",
                            "content": "3 May. Bistritz.--Left Munich at 8:35 P. M., on 1st May, arriving at Vienna early next morning; should have arrived at 6:46, but train was an hour late. Buda-Pesth seems a wonderful place, from the glimpse which I got of it from the train and the little I could see of the streets. I feared to go very far from the station, as we had arrived late and would start as near the correct time as possible. The impression I had was that we were leaving the West and entering the East; the most western of splendid bridges over the Danube, which is here of noble width and depth, took us among the traditions of Turkish rule.\n\nWe left in pretty good time, and came after nightfall to Klausenburgh. Here I stopped for the night at the Hotel Royale. I had for dinner, or rather supper, a chicken done up some way with red pepper, which was very good but thirsty. (Mem., get recipe for Mina.) I asked the waiter, and he said it was called 'paprika hendl', and that, as it was a national dish, I should be able to get it anywhere along the Carpathians.\n\nI found my smattering of German very useful; indeed, I don't know how I should be able to get on without it."
                        },
                        {
                            "number": 2,
                            "title": "CHAPTER II: Jonathan Harker's Journal",
                            "content": "5 May.--I must have been asleep, for certainly if I had not dreamt, the night would have seemed endless. I awoke in my own bed. If it be that I had not dreamt, the Count must have carried me here. I tried to satisfy myself that it was all a nightmare, but I got up and looked out of the window. The castle was bathed in cold moonlight, and every detail stood out sharp and clear. Across the courtyard, I saw Count Dracula's tall figure emerging from a window below. With horror, I saw him crawl face downwards down the castle wall over that dreadful abyss, face down, just as a lizard moves along a wall!"
                        },
                        {
                            "number": 3,
                            "title": "CHAPTER III: The Three Sisters",
                            "content": "When I found that I was a prisoner a sort of wild feeling came over me. I rushed up and down the stairs, trying every door and peering out of every window. In the south corridor, I found a room where the furniture was comfortable. The evening sunlight was warm, and in the stillness I must have fallen asleep. When I opened my eyes, three young women stood before me, their teeth gleaming white like pearls against the ruby of their voluptuous lips. One said: 'Go on! You are first, and we shall follow; yours is the right to begin.'"
                        }
                    ]
                },
                {
                    "id": "77777777-7777-7777-7777-777777777777",
                    "title": "The Legend of Sleepy Hollow",
                    "author": "Washington Irving",
                    "genre": "Folklore",
                    "chapter": "Chapter I",
                    "synopsis": "A drowsy, dreamy influence hangs over Sleepy Hollow, where schoolmaster Ichabod Crane encounters the legendary Headless Horseman.",
                    "content": "In the bosom of one of those spacious coves which indent the eastern shore of the Hudson, at that broad expansion of the river denominated by the ancient Dutch navigators the Tappan Zee, there lies a small market town or rural port, which by some is called Greensburgh, but which is more generally and properly known by the name of Tarry Town.",
                    "read_time_minutes": 5,
                    "cover_image_name": "cover_sleepy",
                    "hero_image_name": "cover_sleepy",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/41/pg41.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 1,
                    "badge_text": "CURATOR PICK",
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Valley of Slumber",
                            "content": "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere. Some say that the place was bewitched by a High German doctor, during the early days of the settlement; others, that an old Indian chief, the prophet or wizard of his tribe, held his powwows there before the country was discovered by Master Hendrick Hudson. Certain it is, the place still continues under the sway of some bewitching power, that holds a spell over the minds of the good people, causing them to walk in a continual reverie.\n\nThe dominant spirit, however, that haunts this enchanted region, and seems to be commander-in-chief of all the powers of the air, is the apparition of a figure on horseback, without a head. It is said by some to be the ghost of a Hessian trooper, whose head had been carried away by a cannon-ball, in some nameless battle during the Revolutionary War."
                        },
                        {
                            "number": 2,
                            "title": "Chapter II: The Chase at the Bridge",
                            "content": "It was the very witching time of night that Ichabod, heavy-hearted and crestfallen, pursued his travels homewards. All the stories of ghosts and goblins that he had heard now came crowding upon his recollection. The night grew darker and darker; the stars seemed to sink deeper in the sky. In the dark shadow of the grove, on the margin of the brook, he beheld something huge, misshapen, black and towering. It stirred not, but seemed gathered up in the gloom, like some gigantic monster ready to spring upon the traveller. Ichabod's hair rose upon his head with terror. The mysterious horseman began to gallop on the other side of the road, keeping pace with Gunpowder!"
                        }
                    ]
                },
                {
                    "id": "88888888-8888-8888-8888-888888888888",
                    "title": "The Metamorphosis",
                    "author": "Franz Kafka",
                    "genre": "Classic Fiction",
                    "chapter": "Chapter I",
                    "synopsis": "Gregor Samsa awakens one morning from troubled dreams to discover he has transformed into a monstrous insect.",
                    "content": "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin. He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections.",
                    "read_time_minutes": 6,
                    "cover_image_name": "cover_metamorphosis",
                    "hero_image_name": "cover_metamorphosis",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/5200/pg5200.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Awakening",
                            "content": "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin. He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections. The bedding was hardly able to cover it and seemed ready to slide off any moment. His many legs, pitifully thin compared with the size of the rest of him, waved about helplessly as he looked.\n\n'What's happened to me?' he thought. It wasn't a dream. His room, a proper human room although a little too small, lay peacefully between its four familiar walls."
                        },
                        {
                            "number": 2,
                            "title": "Chapter II: The Household Dilemma",
                            "content": "It was not until dusk that Gregor awoke from his deep and coma-like sleep. He would certainly have woken not much later without being disturbed, as he felt he had rested and had enough sleep, but it seemed to him that he had been woken by hurried steps and the sound of the door to the hall being cautiously shut. The light of the electric street lamps shone in sickly pale patches onto the ceiling and the upper parts of the furniture, but down where Gregor was it was dark."
                        },
                        {
                            "number": 3,
                            "title": "Chapter III: Departure",
                            "content": "Gregor's serious wound, from which he suffered for over a month—the apple remained lodged in his flesh as a visible reminder, since no one dared remove it—seemed to have reminded even his father that Gregor was a member of the family, in spite of his present pathetic and disgusting shape, who could not be treated as an enemy; that, on the contrary, family duty required them to swallow their disgust and endure him, nothing more."
                        }
                    ]
                },
                {
                    "id": "99999999-9999-9999-9999-999999999999",
                    "title": "The Tell-Tale Heart",
                    "author": "Edgar Allan Poe",
                    "genre": "Gothic",
                    "chapter": "Chapter I",
                    "synopsis": "An unnamed narrator insists upon their sanity while chronicling the methodical murder of an old man with a vulture eye.",
                    "content": "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them. Above all was the sense of hearing acute.",
                    "read_time_minutes": 4,
                    "cover_image_name": "cover_telltale",
                    "hero_image_name": "cover_telltale",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/2148/pg2148.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Vulture Eye",
                            "content": "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them. Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story.\n\nIt is impossible to say how first the idea entered my brain; but once conceived, it haunted me day and night. Object there was none. Passion there was none. I loved the old man. He had never wronged me. He had never given me insult. For his gold I had no desire. I think it was his eye! yes, it was this! He had the eye of a vulture — a pale blue eye, with a film over it. Whenever it fell upon me, my blood ran cold; and so by degrees — very gradually — I made up my mind to take the life of the old man, and thus rid myself of the eye forever."
                        },
                        {
                            "number": 2,
                            "title": "Chapter II: Beneath the Floorboards",
                            "content": "The officers were satisfied. My manner had convinced them. I was singularly at ease. They sat, and while I answered cheerily, they chatted of familiar things. But, ere long, I felt myself getting pale and wished them gone. My head ached, and I fancied a ringing in my ears: but still they sat and still chatted. The ringing became more distinct: — It continued and became more distinct: I talked more freely to get rid of the feeling: but it continued and gained definiteness — until, at length, I found that the noise was not within my ears.\n\nNo doubt I now grew very pale; — but I talked more fluently, and with a heightened voice. Yet the sound increased — and what could I do? It was a low, dull, quick sound — much such a sound as a watch makes when enveloped in cotton."
                        }
                    ]
                },
                {
                    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                    "title": "The Legend of Maria Makiling",
                    "author": "Jose Rizal",
                    "genre": "Folklore",
                    "chapter": "Chapter I",
                    "synopsis": "The celestial guardian of Mount Makiling blesses the villagers with harvest and protection until betrayal silences her valley.",
                    "content": "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods... Her voice was like the murmur of crystal water over white pebbles, and her step was as light as the dewdrop falling upon a leaf at dawn.",
                    "read_time_minutes": 5,
                    "cover_image_name": "cover_maria",
                    "hero_image_name": "cover_maria",
                    "cover_image_url": None,
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Maiden of the Mountain",
                            "content": "According to common belief, Mount Makiling is haunted by a fantastic creature, half nymph, half sylph, called Maria Makiling. She was a beautiful maiden who never grew old. The few hunters and woodsmen who had caught sight of her described her as tall, graceful, with large, luminous black eyes and long, abundant hair that fell almost to her ankles.\n\nShe was known to be kind and compassionate to the poor villagers. When poor folk asked for a ginger root from her garden on the mountainside, it would turn into solid gold by the time they reached their humble huts at the foot of the volcano."
                        }
                    ]
                },
                {
                    "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                    "title": "Frankenstein",
                    "author": "Mary Shelley",
                    "genre": "Gothic",
                    "chapter": "Chapter I",
                    "synopsis": "Victor Frankenstein uncovers the secret of animation, giving life to a creature that turns into his relentless tormentor.",
                    "content": "You will rejoice to hear that no disaster has accompanied the commencement of an enterprise which you have regarded with such evil forebodings. I arrived here yesterday, and my first task is to assure my dear sister of my welfare.",
                    "read_time_minutes": 8,
                    "cover_image_name": "cover_dracula",
                    "hero_image_name": "hero_dracula",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/84/pg84.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Spark of Being",
                            "content": "It was on a dreary night of November that I beheld the accomplishment of my toils. With an anxiety that almost amounted to agony, I collected the instruments of life around me, that I might infuse a spark of being into the lifeless thing that lay at my feet. It was already one in the morning; the rain pattered dismally against the panes, and my candle was nearly burnt out, when, by the glimmer of the half-extinguished light, I saw the dull yellow eye of the creature open; it breathed hard, and a convulsive motion agitated its limbs."
                        }
                    ]
                },
                {
                    "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
                    "title": "The Odyssey",
                    "author": "Homer",
                    "genre": "Mythology",
                    "chapter": "Book I",
                    "synopsis": "Ten years after the fall of Troy, Odysseus wanders across treacherous seas while Penelope fends off suitors in Ithaca.",
                    "content": "Tell me, O Muse, of that ingenious hero who travelled far and wide after he had sacked the famous town of Troy. Many cities did he visit, and many were the nations with whose manners and customs he was acquainted.",
                    "read_time_minutes": 9,
                    "cover_image_name": "cover_dracula",
                    "hero_image_name": "hero_dracula",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/1727/pg1727.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Book I: The Council of the Gods",
                            "content": "Tell me, O Muse, of that ingenious hero who travelled far and wide after he had sacked the famous town of Troy. Many cities did he visit, and many were the nations with whose manners and customs he was acquainted; moreover he suffered much by sea while trying to save his own life and bring his men home safely. But he could not save his men, for they perished through their own sheer folly in eating the cattle of the Sun-god Hyperion; so the god prevented them from ever reaching home."
                        }
                    ]
                },
                {
                    "id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
                    "title": "Alice's Adventures in Wonderland",
                    "author": "Lewis Carroll",
                    "genre": "Classic Fiction",
                    "chapter": "Chapter I",
                    "synopsis": "A curious young girl follows a White Rabbit down a rabbit-hole into a nonsensical underground dream world.",
                    "content": "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it.",
                    "read_time_minutes": 5,
                    "cover_image_name": "cover_metamorphosis",
                    "hero_image_name": "cover_metamorphosis",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/11/pg11.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "CHAPTER I: Down the Rabbit-Hole",
                            "content": "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, 'and what is the use of a book,' thought Alice 'without pictures or conversations?'\n\nSo she was considering in her own mind (as well as she could, for the hot day made her feel very sleepy and stupid), whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies, when suddenly a White Rabbit with pink eyes ran close by her."
                        }
                    ]
                },
                {
                    "id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
                    "title": "The Picture of Dorian Gray",
                    "author": "Oscar Wilde",
                    "genre": "Gothic",
                    "chapter": "Chapter I",
                    "synopsis": "A young aristocrat trades his soul for eternal youth while his painted portrait bears the scars of his sins and decay.",
                    "content": "The studio was filled with the rich odour of roses, and when the light summer wind stirred amidst the trees of the garden, there came through the open door the heavy scent of the lilac.",
                    "read_time_minutes": 6,
                    "cover_image_name": "cover_dracula",
                    "hero_image_name": "hero_dracula",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/174/pg174.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "CHAPTER I: The Studio Portrait",
                            "content": "The studio was filled with the rich odour of roses, and when the light summer wind stirred amidst the trees of the garden, there came through the open door the heavy scent of the lilac, or the more delicate perfume of the pink-flowering thorn.\n\nFrom the corner of the divan of Persian saddle-bags on which he was lying, smoking, as was his custom, innumerable cigarettes, Lord Henry Wotton could just catch the gleam of the honey-sweet and honey-coloured blossoms of a laburnum, whose tremulous branches seemed hardly able to bear the weight of a beauty so flame-like as their own."
                        }
                    ]
                },
                {
                    "id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
                    "title": "Grimms' Fairy Tales",
                    "author": "Brothers Grimm",
                    "genre": "Folklore",
                    "chapter": "Chapter I",
                    "synopsis": "Timeless German folk tales gathered from rural oral tradition, featuring enchantments, golden balls, and talking frogs.",
                    "content": "One fine evening a young princess put on her bonnet and clogs, and went out to take a walk by herself in a wood; and when she came to a cool spring of water, that rose in the midst of it, she sat herself down to rest a while.",
                    "read_time_minutes": 5,
                    "cover_image_name": "cover_sleepy",
                    "hero_image_name": "cover_sleepy",
                    "cover_image_url": "https://www.gutenberg.org/cache/epub/2591/pg2591.cover.medium.jpg",
                    "is_tale_of_the_day": 0,
                    "is_recent_submission": 1,
                    "is_curator_spotlight": 0,
                    "badge_text": None,
                    "chapters": [
                        {
                            "number": 1,
                            "title": "Chapter I: The Frog Prince",
                            "content": "One fine evening a young princess put on her bonnet and clogs, and went out to take a walk by herself in a wood; and when she came to a cool spring of water, that rose in the midst of it, she sat herself down to rest a while. Now she had a golden ball in her hand, which was her favourite plaything; and she was always tossing it up into the air, and catching it again as it fell.\n\nAfter a time she threw it up so high that she missed catching it as it fell; and the ball bounced away, and rolled along upon the ground, till at last it fell down into the spring. The water was very deep, so deep that she could not see the bottom of it. Then she began to bewail her loss, and said, 'Alas! if I could only get my ball again, I would give all my clothes and jewels, and everything that I have in the world.'"
                        }
                    ]
                }
            ]

            for s in seed_catalog:
                total_chapters = len(s.get("chapters", []))
                conn.execute("""
                    INSERT INTO stories (
                        id, title, author, genre, chapter, synopsis, content,
                        read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                        cover_image_name, hero_image_name, cover_image_url, is_tale_of_the_day,
                        is_recent_submission, is_curator_spotlight, badge_text, total_chapters
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    s["id"], s["title"], s["author"], s["genre"], s["chapter"],
                    s["synopsis"], s["content"], s["read_time_minutes"], 0, 0,
                    now_iso, now_iso, s.get("cover_image_name"), s.get("hero_image_name"),
                    s.get("cover_image_url"), s.get("is_tale_of_the_day", 0),
                    s.get("is_recent_submission", 0), s.get("is_curator_spotlight", 0),
                    s.get("badge_text"), max(1, total_chapters)
                ))

                for ch in s.get("chapters", []):
                    ch_id = str(uuid4())
                    words = len(ch["content"].split())
                    conn.execute("""
                        INSERT INTO chapters (
                            id, story_id, chapter_number, title, content, word_count, created_at_utc
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (
                        ch_id, s["id"], ch["number"], ch["title"], ch["content"], words, now_iso
                    ))
    conn.close()

init_db()

def row_to_story_dto(r: sqlite3.Row, include_chapters: bool = False, conn: Optional[sqlite3.Connection] = None) -> StoryDTO:
    story_id = UUID(r["id"])
    chapters = None
    if include_chapters and conn:
        ch_rows = conn.execute(
            "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
            (str(story_id),)
        ).fetchall()
        chapters = [
            ChapterDTO(
                id=UUID(ch["id"]),
                story_id=story_id,
                chapter_number=ch["chapter_number"],
                title=ch["title"],
                content=ch["content"],
                word_count=ch["word_count"],
                created_at_utc=datetime.fromisoformat(ch["created_at_utc"])
            )
            for ch in ch_rows
        ]

    keys = r.keys()
    total_chapters = r["total_chapters"] if "total_chapters" in keys and r["total_chapters"] else 1
    return StoryDTO(
        id=story_id,
        title=r["title"],
        author=r["author"],
        genre=r["genre"],
        chapter=r["chapter"],
        synopsis=r["synopsis"],
        content=r["content"],
        read_time_minutes=r["read_time_minutes"],
        is_bookmarked=bool(r["is_bookmarked"]),
        is_completed=bool(r["is_completed"]),
        created_at_utc=datetime.fromisoformat(r["created_at_utc"]),
        updated_at_utc=datetime.fromisoformat(r["updated_at_utc"]),
        cover_image_name=r["cover_image_name"] if "cover_image_name" in keys else None,
        hero_image_name=r["hero_image_name"] if "hero_image_name" in keys else None,
        cover_image_url=r["cover_image_url"] if "cover_image_url" in keys else None,
        total_pages=r["total_pages"] if "total_pages" in keys and r["total_pages"] else 5,
        current_page=r["current_page"] if "current_page" in keys and r["current_page"] else 1,
        progress_percent=r["progress_percent"] if "progress_percent" in keys and r["progress_percent"] is not None else 0,
        rating=r["rating"] if "rating" in keys and r["rating"] else 4.9,
        saves_count=r["saves_count"] if "saves_count" in keys and r["saves_count"] else "1.2k",
        reads_count=r["reads_count"] if "reads_count" in keys and r["reads_count"] else "1.2k",
        is_tale_of_the_day=bool(r["is_tale_of_the_day"]) if "is_tale_of_the_day" in keys else False,
        is_recent_submission=bool(r["is_recent_submission"]) if "is_recent_submission" in keys else False,
        is_curator_spotlight=bool(r["is_curator_spotlight"]) if "is_curator_spotlight" in keys else False,
        badge_text=r["badge_text"] if "badge_text" in keys else None,
        total_chapters=total_chapters,
        chapters=chapters
    )

@app.get("/api/v1/health", response_model=HealthResponse)
def health_check():
    conn = get_db()
    conn.execute("SELECT 1")
    conn.close()
    return HealthResponse(
        status="healthy",
        database="connected",
        timestamp_utc=datetime.now(timezone.utc)
    )

@app.get("/api/v1/stories", response_model=list[StoryDTO])
def get_stories(
    genre: Optional[str] = None,
    search: Optional[str] = None,
    since: Optional[datetime] = None
):
    conn = get_db()
    query = "SELECT * FROM stories WHERE 1=1"
    params = []

    if genre and genre.lower() != "all":
        query += " AND LOWER(genre) = LOWER(?)"
        params.append(genre)

    if search:
        query += " AND (LOWER(title) LIKE ? OR LOWER(synopsis) LIKE ? OR LOWER(author) LIKE ?)"
        term = f"%{search.lower()}%"
        params.extend([term, term, term])

    if since:
        query += " AND updated_at_utc > ?"
        params.append(since.isoformat())

    query += " ORDER BY is_tale_of_the_day DESC, created_at_utc DESC"
    rows = conn.execute(query, params).fetchall()
    results = [row_to_story_dto(r, include_chapters=False) for r in rows]
    conn.close()
    return results

@app.get("/api/v1/stories/{story_id}", response_model=StoryDTO)
def get_story_by_id(story_id: UUID):
    conn = get_db()
    row = conn.execute("SELECT * FROM stories WHERE id = ?", (str(story_id),)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Story not found")
    story = row_to_story_dto(row, include_chapters=True, conn=conn)
    conn.close()
    return story

@app.get("/api/v1/stories/{story_id}/chapters", response_model=list[ChapterDTO])
def get_story_chapters(story_id: UUID):
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM chapters WHERE story_id = ? ORDER BY chapter_number ASC",
        (str(story_id),)
    ).fetchall()
    conn.close()

    if not rows:
        return []

    return [
        ChapterDTO(
            id=UUID(r["id"]),
            story_id=story_id,
            chapter_number=r["chapter_number"],
            title=r["title"],
            content=r["content"],
            word_count=r["word_count"],
            created_at_utc=datetime.fromisoformat(r["created_at_utc"])
        )
        for r in rows
    ]

@app.get("/api/v1/stories/{story_id}/chapters/{chapter_number}", response_model=ChapterDTO)
def get_story_chapter_by_number(story_id: UUID, chapter_number: int):
    conn = get_db()
    row = conn.execute(
        "SELECT * FROM chapters WHERE story_id = ? AND chapter_number = ?",
        (str(story_id), chapter_number)
    ).fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail=f"Chapter {chapter_number} not found for story")

    return ChapterDTO(
        id=UUID(row["id"]),
        story_id=story_id,
        chapter_number=row["chapter_number"],
        title=row["title"],
        content=row["content"],
        word_count=row["word_count"],
        created_at_utc=datetime.fromisoformat(row["created_at_utc"])
    )

@app.post("/api/v1/stories", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
def create_story(payload: CreateStoryRequest):
    story_id = str(uuid4())
    chapter_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    chapter_title = payload.chapter or "Chapter I"

    conn = get_db()
    with conn:
        conn.execute("""
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                is_recent_submission, total_chapters
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            story_id,
            payload.title,
            payload.author,
            payload.genre,
            chapter_title,
            payload.synopsis,
            payload.content,
            payload.read_time_minutes,
            0,
            0,
            now_iso,
            now_iso,
            1,
            1
        ))

        # Persist Chapter 1 into chapters table
        words = len(payload.content.split())
        conn.execute("""
            INSERT INTO chapters (
                id, story_id, chapter_number, title, content, word_count, created_at_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            chapter_id, story_id, 1, chapter_title, payload.content, words, now_iso
        ))

    conn.close()

    return StoryDTO(
        id=UUID(story_id),
        title=payload.title,
        author=payload.author,
        genre=payload.genre,
        chapter=chapter_title,
        synopsis=payload.synopsis,
        content=payload.content,
        read_time_minutes=payload.read_time_minutes,
        is_bookmarked=False,
        is_completed=False,
        created_at_utc=now,
        updated_at_utc=now,
        is_recent_submission=True,
        total_chapters=1
    )

@app.post("/api/v1/shelf/sync", response_model=ShelfSyncResponse)
def sync_shelf(payload: ShelfSyncPayload):
    conn = get_db()
    reconciled: list[ShelfSyncItemDTO] = []

    with conn:
        for item in payload.items:
            story_id_str = str(item.story_id)
            row = conn.execute(
                "SELECT * FROM shelf_items WHERE story_id = ?",
                (story_id_str,)
            ).fetchone()

            if row is None:
                conn.execute("""
                    INSERT INTO shelf_items (story_id, reading_progress, is_bookmarked, is_completed, updated_at_utc)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    story_id_str,
                    item.reading_progress,
                    1 if item.is_bookmarked else 0,
                    1 if item.is_completed else 0,
                    item.updated_at_utc.isoformat()
                ))
                reconciled.append(item)
            else:
                server_time = datetime.fromisoformat(row["updated_at_utc"])
                client_time = item.updated_at_utc

                if client_time > server_time:
                    conn.execute("""
                        UPDATE shelf_items
                        SET reading_progress = ?, is_bookmarked = ?, is_completed = ?, updated_at_utc = ?
                        WHERE story_id = ?
                    """, (
                        item.reading_progress,
                        1 if item.is_bookmarked else 0,
                        1 if item.is_completed else 0,
                        item.updated_at_utc.isoformat(),
                        story_id_str
                    ))
                    reconciled.append(item)
                else:
                    reconciled.append(ShelfSyncItemDTO(
                        story_id=UUID(row["story_id"]),
                        reading_progress=row["reading_progress"],
                        is_bookmarked=bool(row["is_bookmarked"]),
                        is_completed=bool(row["is_completed"]),
                        updated_at_utc=server_time
                    ))
    conn.close()

    return ShelfSyncResponse(
        status="ok",
        reconciled_items=reconciled,
        server_time_utc=datetime.now(timezone.utc)
    )

@app.post("/api/v1/stories/ingest/{gutenberg_id}", response_model=StoryDTO, status_code=status.HTTP_201_CREATED)
async def ingest_gutenberg_book(
    gutenberg_id: int,
    genre: Optional[str] = Query(default="Folklore")
):
    """
    Live Ingestion Engine: Fetches full plain text from Project Gutenberg, parses
    actual chapters, extracts metadata, and stores into Fable database.
    """
    text_url = f"https://www.gutenberg.org/ebooks/{gutenberg_id}.txt.utf-8"
    meta_url = f"https://gutendex.com/books/?ids={gutenberg_id}"

    title = f"Gutenberg Classic #{gutenberg_id}"
    author = "Public Domain"
    cover_url = f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.cover.medium.jpg"
    synopsis = f"Authentic public-domain edition #{gutenberg_id} from Project Gutenberg."

    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            meta_res = await client.get(meta_url, headers=headers)
            if meta_res.status_code == 200:
                results = meta_res.json().get("results", [])
                if results:
                    book_meta = results[0]
                    title = book_meta.get("title", title)
                    authors = book_meta.get("authors", [])
                    if authors:
                        raw_name = authors[0].get("name", author)
                        if ", " in raw_name:
                            p = raw_name.split(", ", 1)
                            author = f"{p[1]} {p[0]}"
                        else:
                            author = raw_name
                    summaries = book_meta.get("summaries", [])
                    if summaries:
                        synopsis = summaries[0]
        except Exception:
            pass

        try:
            txt_res = await client.get(text_url, headers=headers)
            if txt_res.status_code != 200:
                raise HTTPException(status_code=400, detail=f"Failed to fetch text from Gutenberg for ID {gutenberg_id}")
            raw_text = txt_res.text
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"External Gutenberg network error: {str(e)}")

    chapters = extract_chapters_from_text(raw_text)
    if not chapters:
        raise HTTPException(status_code=422, detail="Unable to extract chapters from manuscript text")

    story_id = str(uuid4())
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    first_chapter = chapters[0]
    total_words = sum(c["word_count"] for c in chapters)
    read_mins = max(3, total_words // 200)

    conn = get_db()
    with conn:
        conn.execute("""
            INSERT INTO stories (
                id, title, author, genre, chapter, synopsis, content,
                read_time_minutes, is_bookmarked, is_completed, created_at_utc, updated_at_utc,
                cover_image_url, is_recent_submission, total_chapters
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            story_id, title[:120], author[:80], genre or "Folklore", first_chapter["title"],
            synopsis[:300], first_chapter["content"], read_mins, 0, 0,
            now_iso, now_iso, cover_url, 1, len(chapters)
        ))

        for ch in chapters:
            ch_id = str(uuid4())
            conn.execute("""
                INSERT INTO chapters (
                    id, story_id, chapter_number, title, content, word_count, created_at_utc
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                ch_id, story_id, ch["chapter_number"], ch["title"], ch["content"], ch["word_count"], now_iso
            ))

    row = conn.execute("SELECT * FROM stories WHERE id = ?", (story_id,)).fetchone()
    dto = row_to_story_dto(row, include_chapters=True, conn=conn)
    conn.close()
    return dto

@app.get("/api/v1/public/gutenberg", response_model=list[StoryDTO])
async def get_gutenberg_stories(
    topic: Optional[str] = Query(default="folklore", description="Topic or genre filter for Gutenberg"),
    search: Optional[str] = Query(default=None, description="Search term across title and author")
):
    """
    Public literature gateway: Queries Project Gutenberg via Gutendex REST API,
    normalizes unstructured literary data into Fable's StoryDTO schema with cover URLs.
    """
    url = "https://gutendex.com/books/"
    params = {}
    if topic and topic.lower() != "all":
        params["topic"] = topic.lower()
    if search:
        params["search"] = search

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(url, params=params, headers=headers)
            if resp.status_code == 200:
                payload = resp.json()
                results = payload.get("results", [])
                gutenberg_stories: list[StoryDTO] = []
                now = datetime.now(timezone.utc)

                for book in results[:10]:
                    book_id = book.get("id", 1000)
                    title = book.get("title", "Untitled Classic")
                    authors = book.get("authors", [])
                    author_name = authors[0].get("name", "Classic Author") if authors else "Public Domain"
                    if ", " in author_name:
                        parts = author_name.split(", ", 1)
                        author_name = f"{parts[1]} {parts[0]}"

                    summaries = book.get("summaries", [])
                    synopsis = summaries[0] if summaries else f"Classic public domain edition of {title} from Project Gutenberg."
                    if len(synopsis) > 280:
                        synopsis = synopsis[:277] + "..."

                    formats = book.get("formats", {})
                    cover_url = formats.get("image/jpeg")

                    subjects = book.get("subjects", [])
                    genre = "Folklore"
                    if any("myth" in s.lower() for s in subjects):
                        genre = "Mythology"
                    elif any("gothic" in s.lower() or "horror" in s.lower() for s in subjects):
                        genre = "Gothic"
                    elif any("fiction" in s.lower() for s in subjects):
                        genre = "Classic Fiction"
                    elif topic and topic.lower() != "all":
                        genre = topic.capitalize()

                    story_uuid = UUID(int=int(book_id))

                    gutenberg_stories.append(StoryDTO(
                        id=story_uuid,
                        title=title[:120],
                        author=author_name[:80],
                        genre=genre,
                        chapter="Chapter I",
                        synopsis=synopsis,
                        content=synopsis,
                        read_time_minutes=max(3, min(12, len(title.split()) * 2)),
                        is_bookmarked=False,
                        is_completed=False,
                        created_at_utc=now,
                        updated_at_utc=now,
                        cover_image_url=cover_url,
                        total_chapters=1
                    ))

                if gutenberg_stories:
                    return gutenberg_stories
    except Exception:
        pass

    return get_stories(genre=topic, search=search)
