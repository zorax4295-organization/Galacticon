---@meta -- permet d'avoir l'autocompletion sans que le fichier ai besoin d'etre ouvert


ic = {}

---@class NaN



--Permet d'écrire sur un périphériques
---@param device integer
---@param logicType LogicType
---@param value number
---@param network integer | nil
---@return nil
function ic.write(device, logicType, value, network) end
--Permet d'écrire sur un périphériques a partir de son id
---@param id integer
---@param logicType LogicType
---@param value number
---@param network integer | nil
---@return nil
function ic.write_id(id, logicType, value, network) end
--Permet d'écrire sur slot d'un périphériques
---@param device integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param network integer | nil
---@return nil
function ic.write_slot(device, slot, slotType, value, network) end
--Permet d'écrire sur slot d'un périphériques a partir de son id
---@param id integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param network integer | nil
---@return nil
function ic.write_slot_id(id, slot, slotType, value, network) end
--Permet d'écrire sur un logicType de plusieurs périphériques en même temps
---@param hash integer
---@param logicType LogicType
---@param value number
---@param network integer | nil
---@return nil
function ic.batch_write(hash, logicType, value, network) end
--Permet d'écrire sur un logicType de plusieurs périphériques en même temps a partir d'un nom
---@param hash integer
---@param nameHash integer
---@param logicType LogicType
---@param value number
---@param network integer | nil
---@return nil
function ic.batch_write_name(hash, nameHash, logicType, value, network) end
--Permet d'écrire sur un slot de plusieurs périphériques en même temps
---@param hash integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param network integer | nil
---@return nil
function ic.batch_write_slot(hash, slot, slotType, value, network) end
--Permet d'écrire sur un slot de plusieurs périphériques en même temps
---@param hash integer
---@param nameHash integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param network integer | nil
---@return nil
function ic.batch_write_slot_name(hash, nameHash, slot, slotType, value, network) end



--Permet de lire un logicType d'un périphérique
---@param device integer
---@param logicType LogicType
---@param network integer | nil
---@return number | nil
function ic.read(device, logicType, network) end
--Permet de lire un logicType sur un périphérique a partir de son id
---@param id integer
---@param logicType LogicType
---@param network integer | nil
---@return number | nil
function ic.read_id(id, logicType, network) end
--Permet de lire un logicSlotType d'un périphérique
---@param device integer
---@param slot integer
---@param slotType LogicSlotType
---@param network integer | nil
---@return number | nil
function ic.read_slot(device, slot, slotType, network) end
--Permet de lire un logicSlotType d'un périphérique a partir de son id
---@param id integer
---@param slot integer
---@param slotType LogicSlotType
---@param network integer | nil
---@return number | nil
function ic.read_slot_id(id, slot, slotType, network) end
--Permet de lire des logicType de plusieurs périphériques
---@param hash integer
---@param logicType LogicType
---@param network integer | nil
---@return number | NaN
function ic.batch_read(hash, logicType, method, network) end
--Permet de lire des logicType de plusieurs périphériques a partir d'un nom
---@param hash integer
---@param nameHash integer
---@param logicType LogicType
---@param network integer | nil
---@return number | NaN
function ic.batch_read_name(hash, nameHash, logicType, method, network) end
--Permet de lire des logicSlotType de plusieurs périphériques
---@param hash integer
---@param slot integer
---@param slotType LogicSlotType
---@param network integer | nil
---@return number | NaN
function ic.batch_read_slot(hash, slot, slotType, method, network) end
--Permet de lire des logicSlotType de plusieurs périphériques a partir d'un nom
---@param hash integer
---@param nameHash integer
---@param slot integer
---@param slotType LogicSlotType
---@param network integer | nil
---@return number | NaN
function ic.batch_read_slot_name(hash, nameHash, slot, slotType, method, network) end



--Arrête la puce et prend feu
function ic.hcf() end
--Récupére l'id d'un périphériques a partir de son nom
---@param name string
---@return integer
function ic.find(name) end
--Liste tous les périphériques d'un réseau
---@param network integer
---@return nil
function ic.device_list(network) end




--Permet de lire une adresse de la mémoire interne de la puce lua
---@param adress integer
---@return number
function mem_read(adress) end
--Permet d'écrire sur une adresse de la mémoire interne de la puce lua
---@param adress integer
---@param value number
---@return nil
function mem_write(adress, value) end
--Permet de lire une adresse de la mémoire interne d'une autre puce lua
---@param device integer
---@param adress integer
---@param network integer | nil
---@return number
function mem_get(device, adress, network) end
--Permet de lire une adresse de la mémoire interne d'une autre puce lua a partire de son id
---@param id integer
---@param adress integer
---@param network integer | nil
---@return number
function mem_get_id(id, adress, network) end
--Permet d'écrire sur une adresse de la mémoire interne d'une autre puce lua
---@param device integer
---@param adress integer
---@param value number
---@param network integer | nil
---@return nil
function mem_put(device, adress, value, network) end
--Permet d'écrire sur une adresse de la mémoire interne d'une autre puce lua a partire de son id
---@param id integer
---@param adress integer
---@param value number
---@param network integer | nil
---@return nil
function mem_put_id(id, adress, value, network) end
--Permet d'éffacer toute la mémoire interne de la puce lua
---@return nil
function mem_clear() end
--Permet d'éffacer toute la mémoire interne d'une autre puce lua
---@param device integer
---@param network integer | nil
---@return nil
function mem_clear_device(device, network) end
--Permet d'éffacer toute la mémoire interne d'une autre puce lua a partire de son id
---@param id integer
---@param network integer | nil
---@return nil
function mem_clear_id(id, network) end



--Permet de hasher un string
---@param nameHash string
---@return number
function hash(nameHash) end
--Permet de retrouver le hash a partire d'un string
---@param hash integer
---@return string | nil
function prefab_name(hash) end





ic.net = {}

--Obtenir son propre id
---@return integer
function ic.net.id() end
--Liste tous les id de puce Lua sur le réseau
---@return table
function ic.net.peers() end
--Enovie un message a une cible précise soit par id soit par nom
---@param target integer | string
---@param channel string
---@param payload number | string | boolean | table | nil
---@return nil
function ic.net.send(target, channel, payload) end
--Enovie un message a tout le monde sur le réseau et renvoie le nombre de puce aillent reçus le message
---@param channel string
---@param payload number | string | boolean | table | nil
---@return integer
function ic.net.broadcast(channel, payload) end
--Reçois un message envoyer par send ou broadcast
---@param sujet string
---@param handler fun(fromId:integer, fromName:string, payload:number | string | boolean | table | nil)
---@return nil
function ic.net.listen(sujet, handler) end

--Publie un sujet a qui bont voudra l'écouter
---@param sujet string
---@param payload number | string | boolean | table | nil
---@param options table | nil
---@return number
function ic.net.publish(sujet, payload , options) end
--S'inscrit pour écouter un sujet
---@param sujet string
---@param handler fun(sujet:string, payload:number | string | boolean | table | nil, fromId:integer, fromName:string, cache:boolean)
---@return nil
function ic.net.subscribe(sujet, handler) end
--Se désincrit d'un sujet
---@param sujet string
---@return nil
function ic.net.unsubscribe(sujet) end