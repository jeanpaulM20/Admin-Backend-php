<?php
class m120907_162016_location extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_location')) {
        	$this->createTable('tbl_location', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'address' => 'string NULL',
				'zip' => 'string NULL',
				'city' => 'string NULL',
				'opening_times' => 'text NULL',
				'e_mail' => 'string NULL',
				'phone' => 'string NULL',
				'foto' => 'string NULL',
				'longitude' => 'string NULL',
				'latitude' => 'string NULL',
				'active' => 'boolean NULL',
				'published' => 'boolean NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_trainer_location')) {
	$this->createTable('tbl_trainer_location', array(
		'trainer_id' => 'integer NOT NULL',
		'location_id' => 'integer NOT NULL',
		'PRIMARY KEY (trainer_id, location_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

			if (!$this->getDbConnection()->getSchema()->getTable('tbl_offer_location')) {
	$this->createTable('tbl_offer_location', array(
		'offer_id' => 'integer NOT NULL',
		'location_id' => 'integer NOT NULL',
		'PRIMARY KEY (offer_id, location_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_location')) {
        	$this->dropTable('tbl_location');
        }
    }
}