enum Weapon:
    laser_gun:
        Int range = 24
        Int attacks = 1
        Int skill = 4
        Int strenght = 3
        Int penetration = 0
        Int damage = 1
    balter_gun:
        Int range = 24
        Int attacks = 2
        Int skill = 3
        Int strenght = 4
        Int penetration = 1
        Int damage = 1


enum Profile:
    baseline_human:
        Int movement = 6 
        Int thoughness = 3 
        Int save = 5 
        Int wounds = 1 
        Int leadership = 7 
    super_human:
        Int movement = 6 
        Int thoughness = 4
        Int save = 3
        Int wounds = 2
        Int leadership = 6

    fun equal(Profile other) -> Bool:
        return self.value == other.value
